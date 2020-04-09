//
//  main.swift
//  Flare
//
//  Created by Chris on 2/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

func printHelp() {
    print("Flare - Simple 2-way sync to Backblaze B2")
    print("")
    print("Usage:")
    print("flare <command>")
    print("")
    print("Commands:")
    print("  configure - you should run this first, this allows you to enter your ")
    print("  schedule  - schedules flare to sync every hour")
    print("  sync      - runs a sync immediately")
    print("")
    print("Examples:")
    print("  flare configure")
    print("  flare sync")
    print("  flare schedule")
    // TODO backup, add backup folder to configuration
}

func runSync() throws {
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

// You could think of this as the 'main' function in this executable. From here on, errors aren't handled, they are simply thrown.
func runAndThrow() throws {
    if CommandLine.arguments.count <= 1 {
        printHelp()
        return
    } else if CommandLine.arguments[1]=="sync" {
        try runSync()
    } else if CommandLine.arguments[1]=="configure" {
        try Configurator.go()
    } else if CommandLine.arguments[1]=="schedule" {
        try Schedule.install()
    } else {
        printHelp()
    }
}
    
// This wraps the throwing code, displaying errors and exiting appropriately.
func runAndExit() {
    do {
        try runAndThrow()
    } catch (let error) {
        print("Error: \(error)")
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
}

// Run everything in a runloop-friendly way.
DispatchQueue.main.async { // This will run when runloop.run() is called. Using OperationQueue.main.addOperation is just as good.
    runAndExit()
}
RunLoop.main.run()
