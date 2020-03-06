//
//  FolderSyncOperation.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This syncs a single folder, and spawns ops for its subfolders.
enum FolderSyncOperation {
    enum Errors: Error {
        case nilAuthToken
        case nilIsDirectory
        case nilContentModificationDate
        case nilFileSize
    }
    
    /// Path is nil for root folder, otherwise something like 'foo/bar/' with a trailing slash.
    /// Returns subfolders.
    static func sync(path: String?, syncContext: SyncContext) throws -> [String] {
        guard let auth = syncContext.authorizeAccountResponse else {
            throw Errors.nilAuthToken
        }
        
        let remoteState = try RemoteSyncListing.list(path: path, syncContext: syncContext)
        
        // Next collect a list of 'local' state.
        // Contents of directory doesn't return '._*' files eg ds store
        // TODO make it skip files that can't be accessed locally eg they're being saved or something, eg mark them as 'skip this!', deal with them next time around?
        let contents = try FileManager.default.myContents(ofDirectory: syncContext.pathUrl(path: path))
        var localStates: [String: SyncFileState] = [:]
        let rootUrl = URL(fileURLWithPath: syncContext.config.folder)
        for file in contents {
            let filePathRelativeToRoot = file.absoluteString.deleting(prefix: rootUrl.absoluteString) // For folders, this'll give us a trailing slash which is what we need to suit bz.
            print("Getting resource values for \(file)")
            let resourceValues = try file.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
            guard let isDirectory = resourceValues.isDirectory else { throw Errors.nilIsDirectory }
            guard let contentModificationDate = resourceValues.contentModificationDate else { throw Errors.nilContentModificationDate }

            if isDirectory { // Add to a set of subfolders, along with local subfolders, so we don't add 2 operations for one folder.
                subfolders.insert(filePathRelativeToRoot) // TODO include the contentModificationDate for comparison.
            } else {
                guard let fileSize = resourceValues.fileSize else { throw Errors.nilFileSize } // Can only get filesize if not a dir.
                localStates[filePathRelativeToRoot] = .exists(contentModificationDate, fileSize, nil)
            }
            // TODO we *need* the watcher to get an accurate idea of local deletions.
            // TODO Maybe upon local deletion, we 'hide' remotely but don't even do a full sync or anything.
            // TODO for local deletions, think about how to model folder deletes, given that if we simply make `.deleted.DATE.FILENAME` in the same folder it'll be lost. Instead create 'FlareRoot/relevant/folder/here/.deleted.foo.filename ? And for sync deletions, *move* to same file?
            // TODO Or maybe on local deletion, create a .deleted.XFILENAME file which this'll then pick up and remove once synced.
            // TODO When sync deletes a file, move it to a 'deleted' folder eg yyyymmd_filename which gets nuked once >1mo.
        }

        // Finally reconcile.
        var actions: [SyncAction] = []
        let remotePlusLocalFiles: Set<String> = Set(localStates.keys).union(remoteStates.keys)
        let oneMonthAgo = Date().addingTimeInterval(-30*24*60*60)
        for file in remotePlusLocalFiles {
            let localState = localStates[file] ?? .missing
            let remoteState = remoteStates[file] ?? .missing
            switch (localState, remoteState) {
            case (.exists(let localDate, let localSize, let localSha1), .exists(let remoteDate, let remoteSize, let remoteSha1)):
                // Do the 3 date comparisons: same/earlier/later:
                if abs(localDate.timeIntervalSince(remoteDate)) < 1 { // Same date.
                    if localSize == remoteSize {
                        // Nothing to do, the sizes and dates are the same.
                        // Don't bother comparing sha1's if both date and size are the same, we can't cover *every* edge case that'll ever occur, we're not going for 5 9's of reliability here, the time spent hashing everything outweighs that.
                    } else if localSize > remoteSize { // Somehow dates match but local is bigger, so i assume bigger is better and upload.
                        // No point looking at sha1's: if the sizes are different, the sha's will certainly be different.
                        actions.append(.upload(file))
                    } else { // Dates match but remote is bigger; bigger is better; download.
                        actions.append(.download(file))
                    }
                } else if localDate > remoteDate {
                    // TODO as an optimisation, if the hashes match, only need to 'touch' the remote file to mark it as synced.
                    // This will mean that even if resyncing a folder, sha's will only be slowly recalculated once, to fix the dates.
                    // Don't cap the file size when loading the local sha1, because it'll still be quicker than up/downloading!
                    actions.append(.upload(file))
                } else {
                    // TODO as an optimisation, if the hashes match, only need to 'touch' the local file to mark it as synced.
                    actions.append(.download(file))
                }
                
            case (.exists(let localDate, _, _), .deleted(let remoteDate)):
                if localDate > remoteDate {
                    actions.append(.upload(file))
                } else {
                    actions.append(.deleteLocal(file))
                }

            case (.exists, .missing):
                actions.append(.upload(file))
                
            case (.deleted(let localDate), .exists(let remoteDate, _, _)):
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
        // TODO if another notification comes in for this folder, then once finishing syncing the next file, restart the folder.

        // TODO compare dates of subfolders, only run a reconciliation if different.
        // Will bz give us a subfolder date that is bumped whenever a child file is changed?
        return Array(subfolders).sorted()
    }
}
