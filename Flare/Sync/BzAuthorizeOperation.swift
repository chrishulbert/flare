//
//  BzAuthorizeOperation.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

class BzAuthorizeOperation: AsyncOperation {
    let syncContext: SyncContext
    init(syncContext: SyncContext) {
        self.syncContext = syncContext
        super.init()
    }
    
    override func asyncStart() {
        AuthorizeAccount.send(accountId: syncContext.config.accountId, applicationKey: syncContext.config.applicationKey, completion: { [weak self] result in
            switch result {
            case .success(let response):
                self?.syncContext.authorizeAccountResponse = response
                self?.asyncFinish()

            case .failure(let error):
                print("Could not authorise: \(error)")
                exit(EXIT_FAILURE)
            }
        })
    }
}
