//
//  ListingReconciliation.swift
//  Flare
//
//  Created by Chris on 6/3/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

struct ListingRecSubfolder {
    let subfolder: String
    let localLastModified: Date?
    let remoteLastModified: Date?
}

struct ListingReconciliation {
    let actions: [SyncAction]
    let subfolders: [ListingRecSubfolder] // Subfolders with different dates.
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
                if abs(localDate.timeIntervalSince(remoteDate)) < 2 { // Same date. Rough time comparison.
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
                
            case (.deleted(let localDate), .deleted):
                // Tidy up metadata so subsequent syncs are faster.
                // Removing metadata is safe, because 'deletes' only happen if both sides have metadata.
                if localDate < oneMonthAgo {
                    actions.append(.clearLocalDeletedMetadata(file))
                }
                // We don't remove remote metadata, because the Bz lifecycle rules auto-delete it for us after a configurable period, and there's no
                // convenient API to manually do it anyway. There's delete_file_version but that makes the previous version active which could be wrong.
                
            case (.deleted(let localDate), .missing):
                if localDate < oneMonthAgo {
                    actions.append(.clearLocalDeletedMetadata(file))
                }
                
            case (.missing, .exists(_, let remoteSize, _)):
                actions.append(.download(file, remoteSize))
                
            case (.missing, .deleted):
                // Do nothing, because Bz lifecycle rules will remove the 'hidden' file soon enough: https://www.backblaze.com/b2/docs/lifecycle_rules.html
                break

            case (.missing, .missing):
                break // Shouldn't be possible.
            }
        }
        
        // TODO set remote folder date to match local folder date, not just the newest date of the contained filesxx
        // Reconcile the subfolders.
        // TODO local folders will be touched when the .DS_Store is added, so some way to push that date up to the server would mean future syncs can skip the folder.xx
        var subfoldersNeedingAttention: [ListingRecSubfolder] = []
        let allSubfoldersSet: Set<String> = Set(local.subfolders.keys).union(remote.subfolders.keys)
        let allSubfolders = allSubfoldersSet.sorted()
        for subfolder in allSubfolders {
            let localDate = local.subfolders[subfolder]
            let remoteDate = remote.subfolders[subfolder]
            if let localDate = localDate, let remoteDate = remoteDate {
                // Exists in both places, so compare dates.
                if abs(localDate.timeIntervalSince(remoteDate)) > 2 { // Different date.
                    print("-s,l,r-")
                    dump(subfolder)
                    dump(localDate)
                    dump(remoteDate)
                    print("-")
                    subfoldersNeedingAttention.append(ListingRecSubfolder(subfolder: subfolder,
                                                                          localLastModified: localDate,
                                                                          remoteLastModified: remoteDate))
                }
            } else { // Subfolder only appears in one of local/remote, so needs syncing.
                subfoldersNeedingAttention.append(ListingRecSubfolder(subfolder: subfolder,
                                                                      localLastModified: localDate,
                                                                      remoteLastModified: remoteDate))
            }
        }
        
        return ListingReconciliation(actions: actions.sorted(), subfolders: subfoldersNeedingAttention)
    }
}
