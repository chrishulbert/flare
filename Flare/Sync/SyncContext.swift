//
//  SyncContext.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This is passed around rather than a singleton to store information.
class SyncContext {
    let config: SyncConfig
    var authorizeAccountResponse: AuthorizeAccountResponse?
    
    init() {
        config = .load()
    }
}
