//
//  SyncManager.swift
//  Flare
//
//  Created by Chris on 29/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This manages the queue of things to do.
class SyncManager {
    static let shared = SyncManager()
    
    let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1 // TODO bump this up to 1 per cpu, and add the appropriate dependencies between ops? Or would that suck for the upload pod reuse?
        q.name = "SyncManager"
        return q
    }()
    
    /// This is exposed so other ops can add themselves as dependencies of this.
    let finalOperation = BlockOperation(block: {
        print("Success!")
        exit(EXIT_SUCCESS)
    })
    
    /// Enqueue the operations necessary to get started.
    func enqueueStart() {
        queue.addOperations([
            BzAuthorizeOperation(syncContext: syncContext),
            FolderSyncOperation(syncContext: syncContext, path: nil),
            finalOperation,
        ], waitUntilFinished: false)
    }
}
