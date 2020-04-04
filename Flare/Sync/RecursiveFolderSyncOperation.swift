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
    
    static func sync(path: String?, syncContext: SyncContext) throws {
        let subfolders = try FolderSyncOperation.sync(path: path, syncContext: syncContext)
        for subfolder in subfolders {
            print("RecursiveFolderSyncOperation - looking in subfolder: \(subfolder)")
            try sync(path: subfolder, syncContext: syncContext)
        }
    }

}
