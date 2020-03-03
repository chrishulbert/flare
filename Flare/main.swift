//
//  main.swift
//  Flare
//
//  Created by Chris on 2/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

// Notes:
// * Unlike dropbox which always consumes ram / cpu, have this scheduled to run hourly *and then quit*.
// * 2500 free requests / day, so 8hrs/day of use, gives you 300 folders.
// * One day make a version that listens for updates and sends immediately.
// * Or maybe just have a mini-app that watches, and if you touch anything, it debounces and spawns this to push up 1min after things slow down, and then quits again, as well as the hourly sync to pull down new stuff. Plus a menu option to 'sync now' if someone else has pushed.
// * Instead of running hourly (what if you open laptop at 3:12 and close at 3:56?) - check every minute if it's been at least an hour since last run. This also solves thundering herd.
// Set bz bucket policy to 'Keep only the last version of the file' (does that keep the 'hidden' record/file/version?)
// Make a config file like so: nano ~/.flare
//    {
//        "key":            "...",
//        "accountId":      "...",
//        "applicationKey": "...",
//        "bucketId":       "...",
//        "folder":         "/Users/foo/Flare"
//    }
// Generate a key for the above with this: ruby -e "require 'securerandom'; require 'base64'; puts(Base64.encode64(SecureRandom.random_bytes(32)))"
// Note that the bucket id isn't the same as the bucket name
// Libuv: https://github.com/Trevi-Swift/swift-libuv
// Libuv: http://docs.libuv.org/en/v1.x/guide/filesystem.html#file-change-events

import Foundation
//import CLibUV

//let demoFileName = "Demo.txt"
//let demoData = "Lorem ipsum".data(using: .utf8)!
//let demoLastModified = Date()
//
//AuthorizeAccount.send(accountId: config.accountId, applicationKey: config.applicationKey, completion: { result in
//    switch result {
//    case .success(let response):
//        GetUploadUrl.send(token: response.authorizationToken, apiUrl: response.apiUrl, bucketId: config.bucketId, completion: { result in
//            switch result {
//            case .success(let uploadParams):
//                Uploader.upload(token: response.authorizationToken, apiUrl: response.apiUrl, bucketId: config.bucketId, uploadParams: uploadParams, fileName: demoFileName, file: demoData, lastModified: demoLastModified, completion: { result in
//                    switch result {
//                    case .success(let uploadParams):
//                        print("Uploaded!")
////                        exit(EXIT_SUCCESS)
//
//
//                    case .failure(let error):
//                        print(error)
//                        exit(EXIT_FAILURE)
//                    }
//                })
//
//            case .failure(let error):
//                print(error)
//                exit(EXIT_FAILURE)
//            }
//        })
                
//        HideFile.send(token: response.authorizationToken, apiUrl: response.apiUrl, bucketId: config.bucketId, fileName: "Icon120.png", completion: { result in
//            switch result {
//            case .success:
//                print("Hidden :)")
//                // NOTE! ListFileVersions returns two records for Icon120.png
//                // First record is action:hide
//                // Second is action:upload
//                // Hide record uploadTimestamp": 1568850170000 IS THE TIME OF DELETION WOO HOO
//
//                ListFileVersions.send(token: response.authorizationToken,
//                                      apiUrl: response.apiUrl,
//                                      bucketId: config.bucketId,
//                                      startFileName: nil,
//                                      startFileId: nil,
//                                      prefix: nil, completion: { result in
//                                        switch result {
//                                        case .success(let files):
//                                            print(files)
//                                            exit(EXIT_SUCCESS)
//
//                                        case .failure(let error):
//                                            print(error)
//                                            exit(EXIT_FAILURE)
//                                        }
//                })
//
//            case .failure(Service.Errors.not200(400, "already_hidden", _)):
//                print("Already hidden")
//                exit(EXIT_SUCCESS)
//
//            case .failure(let error):
//                print(error)
//                exit(EXIT_FAILURE)
//            }
//        })
        
//    case .failure(let error):
//        print(error)
//        exit(EXIT_FAILURE)
//    }
//})

//let witness = Witness(paths: [config.folder], flags: [.FileEvents, .IgnoreSelf], latency: 1) { events in
//    // If a file is renamed, you get a 'renamed' event for both the old and new name.
//    // TODO ignore .DS_Store
//    print("file system events received:")
//    for event in events {
//        print(event)
//    }
//    print("---")
//}

// You could think of this as the 'main' function in this executable. From here on, errors aren't handled, they are simply thrown.
func runAndThrow() throws {
    let syncContext = try SyncContext()
    let auth = try AuthorizeAccount.send(accountId: syncContext.config.accountId, applicationKey: syncContext.config.applicationKey)
    syncContext.authorizeAccountResponse = auth
    let myData = "sdfgsdfgsdfg".data(using: .utf8)!

    var files = try ListAllFileVersions.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, prefix: "foo/bar/", delimiter: "/")
    print("---initial:---")
    print(files)
    print("------")
    
    var uploadParams = try GetUploadUrl.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId)
    uploadParams = try Uploader.upload(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, uploadParams: uploadParams, fileName: "newfolder/blah.txt", file: myData, lastModified: Date())
    files = try ListAllFileVersions.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, prefix: nil, delimiter: "/")
    print("---after uploading blah.txt:---")
    print(files)
    print("------")

    let past = Date().addingTimeInterval(-24*60*60)
    uploadParams = try UploaderWithFolderModifications.upload(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, uploadParams: uploadParams, fileName: "foo/bar/yada/blah.txt", file: myData, lastModified: past)
    
    sleep(10)

    uploadParams = try GetUploadUrl.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId)
    uploadParams = try Uploader.upload(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, uploadParams: uploadParams, fileName: "newfolder/yada.txt", file: myData, lastModified: Date())
    files = try ListAllFileVersions.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, prefix: nil, delimiter: "/")
    print("---after uploading yada.txt:---")
    print(files)
    print("------")

    sleep(10)
    
    uploadParams = try GetUploadUrl.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId)
    uploadParams = try Uploader.upload(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, uploadParams: uploadParams, fileName: "newfolder/yada2.txt", file: myData, lastModified: Date())
    files = try ListAllFileVersions.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, prefix: nil, delimiter: "/")
    print("---after uploading yada2.txt:---")
    print(files)
    print("------")
    
    sleep(10)
    
    uploadParams = try GetUploadUrl.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId)
    uploadParams = try Uploader.upload(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, uploadParams: uploadParams, fileName: "newfolder/yada3.txt", file: myData, lastModified: Date())
    files = try ListAllFileVersions.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, prefix: nil, delimiter: "/")
    print("---after uploading yada3.txt:---")
    print(files)
    print("------")
    
    //try RecursiveFolderSyncOperation.sync(path: nil, syncContext: syncContext)
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
