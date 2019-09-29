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
        q.maxConcurrentOperationCount = 1
        q.name = "SyncManager"
        return q
    }()
}
