//
//  AsyncOperation.swift
//  Flare
//
//  Created by Chris on 29/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

// Wrapper for the difficult KVO in Operation.
// https://github.com/chrishulbert/S3Sync/blob/master/S3Sync/SyncConcurrentOperation.m
// https://github.com/TwoRingSoft/Pippin/blob/707f96e11a9a0db9404e885dbdb8384309710ab1/Sources/Pippin/Extensions/Foundation/NSOperation/AsyncOperation.swift
class AsyncOperation: Operation {
    /// Apple docs say not to call super.
    override func start() {
        guard !isCancelled else {
            asyncFinish()
            return
        }
        
        setIsExecutingWithKVO(value: true)
        asyncStart()
    }
    
    /// Override this (no need to call super) to start your code.
    func asyncStart() {}
    
    /// Call this when you're done.
    func asyncFinish() {
        setIsExecutingWithKVO(value: false)
        setIsFinishedWithKVO(value: true)
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    // MARK: KVO
    
    // Cannot simply override the existing named fields because they are get-only and we need KVO.
    private var myFinished = false
    private var myExecuting = false
    
    override var isFinished: Bool {
        return myFinished
    }
    
    override var isExecuting: Bool {
        return myExecuting
    }
    
    func setIsFinishedWithKVO(value: Bool) {
        willChangeValue(forKey: "isFinished")
        myFinished = value
        didChangeValue(forKey: "isFinished")
    }

    func setIsExecutingWithKVO(value: Bool) {
        willChangeValue(forKey: "isExecuting")
        myExecuting = value
        didChangeValue(forKey: "isExecuting")
    }
}
