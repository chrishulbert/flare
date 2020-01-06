//
//  BzAuthorizeOperation.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

enum BzAuthorizeOperation {
    static func authorize(syncContext: SyncContext) throws {
        let response = try AuthorizeAccount.send(accountId: syncContext.config.accountId, applicationKey: syncContext.config.applicationKey)
        syncContext.authorizeAccountResponse = response
    }
}
