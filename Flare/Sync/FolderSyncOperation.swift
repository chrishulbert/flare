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
        let contentsRaw = try? FileManager.default.contentsOfDirectory(at: pathUrl,
                                                                       includingPropertiesForKeys: [URLResourceKey.isDirectoryKey, .contentModificationDateKey],
                                                                       options: .skipsHiddenFiles)
        guard let contents = contentsRaw else {
            // TODO handle this gracefully eg there's no such local folder, which is fine, needs to be synced down.
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
            let op = FolderSyncOperation(syncContext: syncContext, path: subfolder)
            SyncManager.shared.finalOperation.addDependency(op) // Ensure my new op runs before the 'final' one.
            SyncManager.shared.queue.addOperation(op)
        }

        // Finally reconcile.
        let localFilesSet: Set<String> = Set(localStates.keys) // Turn these into sets for scalable comparisons.
        let remoteFilesSet: Set<String> = Set(remoteStates.keys)
        let remotesPlusLocals: Set<String> = localFilesSet.union(remoteFilesSet)
        for file in remotesPlusLocals {
            print("Reconcile >\(file)<")
            let inLocal = localFilesSet.contains(file)
            let inRemote = remoteFilesSet.contains(file)
            if inLocal && inRemote {
                // TODO compare dates, or maybe one will be 'deleted' or whatever.
                // TODO deleted gets lower priority.
                // TODO compare hashes if dates are different? Same hash means touch the dates to match?
                print(" in both")
            } else if inLocal && !inRemote {
                // Compare if one is deleted or inserted or whatever.
                print(" in only local")
            } else if !inLocal && inRemote {
                // Compare if one is deleted or inserted or whatever.
                print(" in only remote")
            }
            print(" /reconcile")
        }
        
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
