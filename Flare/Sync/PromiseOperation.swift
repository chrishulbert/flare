//
//  PromiseOperation.swift
//  Flare
//
//  Created by Chris on 2/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This is an async operation, but more in line with JS-style promise syntax.
/// Eg you pass it your closure with your code, and your closure has to call
/// the 'completed' hander it is passed as the argument when done.
class PromiseOperation: AsyncOperation {
    
    typealias PromiseClosure = (@escaping () -> ()) -> ()
    
    let closure: PromiseClosure
    
    init(closure: @escaping PromiseClosure) {
        self.closure = closure
        super.init()
    }
    
    override func asyncStart() {
        closure { [weak self] in
            self?.asyncFinish()
        }
    }
    
}
