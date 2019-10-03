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
    let path: String
    init(syncContext: SyncContext, path: String) {
        self.syncContext = syncContext
        self.path = path
        super.init()
    }
    
    override func asyncStart() {
        <#code#>
    }
}
