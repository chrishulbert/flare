//
//  main.swift
//  Flare
//
//  Created by Chris on 2/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

// Libuv: https://github.com/Trevi-Swift/swift-libuv
// Libuv: http://docs.libuv.org/en/v1.x/guide/filesystem.html#file-change-events

import Foundation
//import CLibUV

// You could think of this as the 'main' function in this executable. From here on, errors aren't handled, they are simply thrown.
func runAndThrow() throws {
    let syncContext = try SyncContext()
    let auth = try AuthorizeAccount.send(accountId: syncContext.config.accountId, applicationKey: syncContext.config.applicationKey)
    syncContext.authorizeAccountResponse = auth
    syncContext.uploadParams = try GetUploadUrl.send(token: auth.authorizationToken,
                                                     apiUrl: auth.apiUrl,
                                                     bucketId: syncContext.config.bucketId)

    try RecursiveFolderSyncOperation.sync(path: nil, syncContext: syncContext)
}
    
// This wraps the throwing code, displaying errors and exiting appropriately.
func runAndExit() {
    do {
        try runAndThrow()
    } catch (let error) {
        print("Error: \(error)")
        exit(EXIT_FAILURE)
    }
    print("Success!")
    exit(EXIT_SUCCESS)
}

// Run everything in a runloop-friendly way.
DispatchQueue.main.async { // This will run when runloop.run() is called. Using OperationQueue.main.addOperation is just as good.
    runAndExit()
}
RunLoop.main.run()
