//
//  SyncManager.swift
//  Flare
//
//  Created by Chris on 29/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This manages the queue of things to do.
/// Even though we're running everything synchronously/blocking,
/// we need to allow the NSRunLoop to run on the main thread for URLSession to work,
/// so this wraps the core logic of the app in its own queue.
class SyncManager {
    static let shared = SyncManager()
    
    let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "SyncManager"
        return q
    }()
    
    /// Enqueue the operations necessary to get started.
    func enqueueStart() {
        queue.addOperation {
            self.startAndHandleErrors()
        }
    }
    
    /// This runs, handling errors gracefully.
    private func startAndHandleErrors() {
        do {
            try startAndThrowErrors()
        } catch (let error) {
            print("Error: \(error)")
            exit(EXIT_FAILURE)
        }
        print("Success!")
        exit(EXIT_SUCCESS)
    }
    
    // You could think of this as the 'main' function in this executable. From here on, errors aren't handled, they are simply thrown.
    private func startAndThrowErrors() throws {
        let syncContext = try SyncContext()
        syncContext.authorizeAccountResponse = try AuthorizeAccount.send(accountId: syncContext.config.accountId, applicationKey: syncContext.config.applicationKey)
        try RecursiveFolderSyncOperation.sync(path: nil, syncContext: syncContext)
    }
    
}
