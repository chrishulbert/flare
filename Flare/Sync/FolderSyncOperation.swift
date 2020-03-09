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
    
    /// Path is nil for root folder, otherwise something like 'foo/bar/' with a trailing slash.
    /// Returns subfolders.
    static func sync(path: String?, syncContext: SyncContext) throws -> [String] {
        let localState = try LocalSyncListing.list(path: path, syncContext: syncContext)
        let remoteState = try RemoteSyncListing.list(path: path, syncContext: syncContext)
        let reconciliation = ListingReconciliation.reconcile(local: localState, remote: remoteState)
        
        // TODO make it skip files that can't be accessed locally eg they're being saved or something, eg mark them as 'skip this!', deal with them next time around?
        // TODO we *need* the watcher to get an accurate idea of local deletions.
        // TODO Maybe upon local deletion, we 'hide' remotely but don't even do a full sync or anything.
        // TODO for local deletions, think about how to model folder deletes, given that if we simply make `.deleted.DATE.FILENAME` in the same folder it'll be lost. Instead create 'FlareRoot/relevant/folder/here/.deleted.foo.filename ? And for sync deletions, *move* to same file?
        // TODO Or maybe on local deletion, create a .deleted.XFILENAME file which this'll then pick up and remove once synced.
        // TODO When sync deletes a file, move it to a 'deleted' folder eg yyyymmd_filename which gets nuked once >1mo.
        
        print("Actions:")
        print(reconciliation.actions)
        print(" /actions")

        // TODO if another notification comes in for this folder, then once finishing syncing the next file, restart the folder.

        return Array(reconciliation.subfolders).sorted()
    }
}
