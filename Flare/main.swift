//
//  main.swift
//  Flare
//
//  Created by Chris on 2/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

// Notes:
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

import Foundation

let demoFileName = "Demo.txt"
let demoData = "Lorem ipsum".data(using: .utf8)!
let demoLastModified = Date()

let config = SyncConfig.load()

AuthorizeAccount.send(accountId: config.accountId, applicationKey: config.applicationKey, completion: { result in
    switch result {
    case .success(let response):
        GetUploadUrl.send(token: response.authorizationToken, apiUrl: response.apiUrl, bucketId: config.bucketId, completion: { result in
            switch result {
            case .success(let uploadParams):
                Uploader.send(token: response.authorizationToken, apiUrl: response.apiUrl, bucketId: config.bucketId, uploadParams: uploadParams, fileName: demoFileName, file: demoData, lastModified: demoLastModified, completion: { result in
                    switch result {
                    case .success(let uploadParams):
                        print("Uploaded!")
                        exit(EXIT_SUCCESS)

                        
                    case .failure(let error):
                        print(error)
                        exit(EXIT_FAILURE)
                    }
                })
                
            case .failure(let error):
                print(error)
                exit(EXIT_FAILURE)
            }
        })
                
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
        
    case .failure(let error):
        print(error)
        exit(EXIT_FAILURE)
    }
})

RunLoop.main.run()
