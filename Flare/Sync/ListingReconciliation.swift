//
//  ListingReconciliation.swift
//  Flare
//
//  Created by Chris on 6/3/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

struct ListingReconciliation {
    let actions: [SyncAction]
    let subfolders: Set<String> // Subfolders with different dates.
}

extension ListingReconciliation {
    /// Reconcile the two listings, figure out the necessary actions. Returns them sorted such that quick actions will happen first.
    static func reconcile(local: LocalSyncListing, remote: RemoteSyncListing) -> ListingReconciliation {
        
        // Create a list of every potential file.
        var allFiles: Set<String> = Set(local.files.keys).union(remote.files.keys)
        allFiles.subtract(local.filesToSkip)
        allFiles.subtract(remote.filesToSkip)
        
        var actions: [SyncAction] = []
        let oneMonthAgo = Date().addingTimeInterval(-30*24*60*60)
        for file in allFiles {
            let localState = local.files[file] ?? .missing
            let remoteState = remote.files[file] ?? .missing
            switch (localState, remoteState) {
            case (.exists(let localDate, let localSize, _ /*let localSha1*/), .exists(let remoteDate, let remoteSize, _ /* let remoteSha1*/)):
                // Do the 3 date comparisons: same/earlier/later:
                if abs(localDate.timeIntervalSince(remoteDate)) < 1 { // Same date.
                    if localSize == remoteSize {
                        // Nothing to do, the sizes and dates are the same.
                        // Don't bother comparing sha1's if both date and size are the same, we can't cover *every* edge case that'll ever occur, we're not going for 5 9's of reliability here, the time spent hashing everything outweighs that.
                    } else if localSize > remoteSize { // Somehow dates match but local is bigger, so i assume bigger is better and upload.
                        // No point looking at sha1's: if the sizes are different, the sha's will certainly be different.
                        actions.append(.upload(file, localSize))
                    } else { // Dates match but remote is bigger; bigger is better; download.
                        actions.append(.download(file, remoteSize))
                    }
                } else if localDate > remoteDate {
                    // TODO as an optimisation, if the hashes match, only need to 'touch' the remote file to mark it as synced. Not sure if the Bz api allows this though.
                    // This will mean that even if resyncing a folder, sha's will only be slowly recalculated once, to fix the dates.
                    // Don't cap the file size when loading the local sha1, because it'll still be quicker than up/downloading!
                    actions.append(.upload(file, localSize))
                } else {
                    // TODO as an optimisation, if the hashes match, only need to 'touch' the local file to mark it as synced.
                    actions.append(.download(file, remoteSize))
                }
                
            case (.exists(let localDate, let localSize, _), .deleted(let remoteDate)):
                if localDate > remoteDate {
                    actions.append(.upload(file, localSize))
                } else {
                    actions.append(.deleteLocal(file))
                }

            case (.exists(_, let localSize, _), .missing):
                actions.append(.upload(file, localSize))
                
            case (.deleted(let localDate), .exists(let remoteDate, let remoteSize, _)):
                if localDate > remoteDate {
                    actions.append(.deleteRemote(file))
                } else {
                    actions.append(.download(file, remoteSize))
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
                
            case (.missing, .exists(_, let remoteSize, _)):
                actions.append(.download(file, remoteSize))
                
            case (.missing, .deleted(let remoteDate)):
                if remoteDate < oneMonthAgo {
                    actions.append(.clearRemoteDeletedMetadata(file))
                }

            case (.missing, .missing):
                break // Shouldn't be possible.
            }
        }
        
        // Reconcile the subfolders.
        var subfoldersNeedingAttention: Set<String> = []
        let allSubfolders: Set<String> = Set(local.subfolders.keys).union(remote.subfolders.keys)
        for subfolder in allSubfolders {
            if let localDate = local.subfolders[subfolder],
                let remoteDate = remote.subfolders[subfolder] {
                // Exists in both places, so compare dates.
                if abs(localDate.timeIntervalSince(remoteDate)) > 1 { // Different date.
                    subfoldersNeedingAttention.insert(subfolder)
                }
            } else { // Subfolder only appears in one of local/remote, so needs syncing.
                subfoldersNeedingAttention.insert(subfolder)
            }
        }
        
        return ListingReconciliation(actions: actions.sorted(), subfolders: subfoldersNeedingAttention)
    }
}
