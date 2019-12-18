//
//  FolderSyncOperation.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This syncs a single folder, and spawns ops for its subfolders.
class FolderSyncOperation: AsyncOperation {
    let syncContext: SyncContext
    let path: String? // Nil for root folder, otherwise something like 'foo/bar/' with a trailing slash.
    init(syncContext: SyncContext, path: String?) {
        self.syncContext = syncContext
        self.path = path
        super.init()
    }
    
    override func asyncStart() {
        guard let auth = syncContext.authorizeAccountResponse else {
            print("Missing auth token")
            exit(EXIT_FAILURE)
        }
        
        print("FolderSyncOperation: \(path ?? ">root<")")
        ListAllFileVersions.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, prefix: path, delimiter: "/", completion: { [weak self] result in
            switch result {
            case .success(let files):
                self?.handle(files: files)
                
            case .failure(let error):
                print("FolderSyncOperation > ListAllFileVersions error: \(error)")
                exit(EXIT_FAILURE)
            }
        })
    }
    
    /// Handle the returned files listing
    func handle(files: [ListFileVersionsFile]) {
        // Firstly collect a list of the 'remote' state.
        // TODO ignore '.bzEmpty' eg empty folder - or is this only a created-by-web-ui thing?
        var subfolders: Set<String> = []
        var remoteStates: [String: SyncFileState] = [:]
        for file in files {
            guard let action = file.actionEnum else { continue }
            switch action {
            case .start:
                // In progress, so don't touch anything - this file can be taken care of next time the sync runs.
                print("Ignoring \(file.fileName) because it's an in-progress upload")
                
            case .upload:
                // Skip if we have already encountered this file, because the first version record is the most recent one.
                guard !remoteStates.keys.contains(file.fileName) else { continue }
                remoteStates[file.fileName] = .exists(file.lastModified)
                
            case .hide:
                // Skip if we have already encountered this file, because the first version record is the most recent one.
                guard !remoteStates.keys.contains(file.fileName) else { continue }
                let when = file.uploadTimestamp.asDate // This is the time it was hidden from bz, not the time it was deleted off the local computer, so not ideal but is reasonable.
                remoteStates[file.fileName] = .deleted(when)

            case .folder: // Queue syncing subfolders.
                subfolders.insert(file.fileName) // Add to a set of subfolders, along with local subfolders, so we don't add 2 operations for one folder.
            }
        }
        
        // Next collect a list of 'local' state.
        // Contents of directory doesn't return '._*' files eg ds store
        // TODO make it skip files that can't be accessed locally eg they're being saved or something, deal with them next time?
        let contentsRaw = try? myContents(ofDirectory: pathUrl)
        guard let contents = contentsRaw else {
            print("Could not read contents of \(pathUrl)")
            exit(EXIT_FAILURE)
        }
        var localStates: [String: SyncFileState] = [:]
        let rootUrl = URL(fileURLWithPath: syncContext.config.folder)
        for file in contents {
            let filePathRelativeToRoot = file.absoluteString.deleting(prefix: rootUrl.absoluteString) // For folders, this'll give us a trailing slash which is great.
            guard let value = try? file.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]) else {
                print("Could not read resource values of \(file)")
                exit(EXIT_FAILURE)
            }
            guard let isDirectory = value.isDirectory else {
                print("Could not read isDirectory of \(file)")
                exit(EXIT_FAILURE)
            }
            guard let contentModificationDate = value.contentModificationDate else {
                print("Could not read contentModificationDate of \(file)")
                exit(EXIT_FAILURE)
            }

            if isDirectory { // Add to a set of subfolders, along with local subfolders, so we don't add 2 operations for one folder.
                subfolders.insert(filePathRelativeToRoot)
            } else {
                localStates[filePathRelativeToRoot] = .exists(contentModificationDate)
            }
            // TODO we *need* the watcher to get an accurate idea of local deletions.
            // TODO Maybe upon local deletion, we 'hide' remotely but don't even do a full sync or anything.
            // TODO Or maybe on local deletion, create a .deleted.XFILENAME file which this'll then pick up and remove once synced.
        }
                
        // Queue subfolders.
        for subfolder in subfolders {
            print("Subfolder: \(subfolder)")
            // TODO compare dates of subfolders, only run a reconciliation if different.
            let op = FolderSyncOperation(syncContext: syncContext, path: subfolder)
            SyncManager.shared.finalOperation.addDependency(op) // Ensure my new op runs before the 'final' one.
            SyncManager.shared.queue.addOperation(op)
        }

        // Finally reconcile.
        var actions: [SyncAction] = []
        let remotePlusLocalFiles: Set<String> = Set(localStates.keys).union(remoteStates.keys)
        let oneMonthAgo = Date().addingTimeInterval(-30*24*60*60)
        for file in remotePlusLocalFiles {
            let localState = localStates[file] ?? .missing
            let remoteState = remoteStates[file] ?? .missing
            switch (localState, remoteState) {
            case (.exists(let localDate), .exists(let remoteDate)):
                if abs(localDate.timeIntervalSince(remoteDate)) < 1 {
                    // Nothing to do, the dates are the same.
                    // TODO Perhaps consider comparing file hashes?
                } else if localDate > remoteDate {
                    actions.append(.upload(file))
                } else {
                    actions.append(.download(file))
                }
                
            case (.exists(let localDate), .deleted(let remoteDate)):
                if localDate > remoteDate {
                    actions.append(.upload(file))
                } else {
                    actions.append(.deleteLocal(file))
                }

            case (.exists, .missing):
                actions.append(.upload(file))
                
            case (.deleted(let localDate), .exists(let remoteDate)):
                if localDate > remoteDate {
                    actions.append(.deleteRemote(file))
                } else {
                    actions.append(.download(file))
                }
                
            case (.deleted(let localDate), .deleted(let remoteDate)):
                // Tidy up metadata so subsequent syncs are faster.
                // Removing metadata is safe, because 'deletes' only happen if both sides have metadata.
                if localDate < oneMonthAgo {
                    actions.append(.clearLocalDeletedMetadata(file))
                }
                if remoteDate < oneMonthAgo {
                    actions.append(.clearRemoteDeletedMetadata(file))
                }
                
            case (.deleted(let localDate), .missing):
                if localDate < oneMonthAgo {
                    actions.append(.clearLocalDeletedMetadata(file))
                }
                
            case (.missing, .exists):
                actions.append(.download(file))
                
            case (.missing, .deleted(let remoteDate)):
                if remoteDate < oneMonthAgo {
                    actions.append(.clearRemoteDeletedMetadata(file))
                }

            case (.missing, .missing):
                break // Shouldn't be possible.
            }
        }
        
        print("Actions:")
        print(actions)
        print(" /actions")
        
        // TODO when doing the actions, do the smallest files first for speed.
        
        asyncFinish()
    }
    
    var pathUrl: URL {
        let root = URL(fileURLWithPath: syncContext.config.folder)
        if let path = path {
            return URL(fileURLWithPath: path, relativeTo: root)
        } else {
            return root
        }
    }
}

enum SyncFileState {
    case exists(Date)
    case deleted(Date)
    case missing
}

extension ListFileVersionsFile {
    /// Grabs the 'last modified' date if it can, otherwise uses the upload timestamp as a backup.
    var lastModified: Date {
        if let millis = fileInfo["src_last_modified_millis"] as? Int {
            return millis.asDate
        } else {
            return uploadTimestamp.asDate
        }
    }
}

extension Int {
    var asDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(self) / 1000)
    }
}

extension String {
    func deleting(prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}

/// Gets the contents of a dir, gracefully returning [] if the dir doesn't exist, thus needs to be synced down.
fileprivate func myContents(ofDirectory: URL) throws -> [URL] {
    do {
        return try FileManager.default.contentsOfDirectory(at: ofDirectory,
            includingPropertiesForKeys: [URLResourceKey.isDirectoryKey, .contentModificationDateKey],
            options: .skipsHiddenFiles)
    } catch (let error as NSError) {
        if error.code == 260 { // No such directory, which is fine, just needs to be synced down.
            return []
        } else {
            throw error // Unknown error we shouldn't ignore.
        }
    }
}

enum SyncAction {
    case upload(String)
    case download(String)
    case deleteLocal(String)
    case deleteRemote(String)
    case clearLocalDeletedMetadata(String)
    case clearRemoteDeletedMetadata(String)
}
