//
//  RecursiveFolderSyncOperation.swift
//  Flare
//
//  Created by Chris on 6/1/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

// This wraps FolderSyncOperation, syncing subfolders.
enum RecursiveFolderSyncOperation {
    
    static func sync(path: String?, localLastModified: Date?, remoteLastModified: Date?, syncContext: SyncContext) throws {
        let subfolders = try FolderSyncOperation.sync(path: path, localLastModified: localLastModified, remoteLastModified: remoteLastModified, syncContext: syncContext)
        for subfolderDetails in subfolders {
            print("RecursiveFolderSyncOperation - looking in subfolder: \(subfolderDetails)")
            try sync(path: subfolderDetails.subfolder,
                     localLastModified: subfolderDetails.localLastModified,
                     remoteLastModified: subfolderDetails.remoteLastModified,
                     syncContext: syncContext)
        }
    }

}
