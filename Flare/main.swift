//
//  main.swift
//  Flare
//
//  Created by Chris on 2/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

// You could think of this as the 'main' function in this executable. From here on, errors aren't handled, they are simply thrown.
func runAndThrow() throws {
    let syncContext = try SyncContext()
    let auth = try AuthorizeAccount.send(accountId: syncContext.config.accountId, applicationKey: syncContext.config.applicationKey)
    syncContext.authorizeAccountResponse = auth
    syncContext.uploadParams = try GetUploadUrl.send(token: auth.authorizationToken,
                                                     apiUrl: auth.apiUrl,
                                                     bucketId: syncContext.config.bucketId)
    let rootUrl = URL(fileURLWithPath: syncContext.config.folder)
    try FileManager.default.createDirectory(at: rootUrl, withIntermediateDirectories: true)
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
