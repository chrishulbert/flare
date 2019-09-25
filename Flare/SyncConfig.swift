//
//  SyncConfig.swift
//  Flare
//
//  Created by Chris on 25/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

struct SyncConfig {
    let key: Data // AES256 eg 32 bytes
    let accountId: String
    let applicationKey: String
    let bucketId: String
    let folder: String
}

extension SyncConfig {
    // Load the config from disk.
    static func load() -> SyncConfig {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flare")
        guard let configData = try? Data(contentsOf: configPath) else {
            print("Could not read config file")
            exit(EXIT_FAILURE)
        }
        guard let configJsonAny = try? JSONSerialization.jsonObject(with: configData, options: []),
            let configJson = configJsonAny as? [AnyHashable: Any] else {
            print("Could not json-parse config file")
            exit(EXIT_FAILURE)
        }
        guard let keyRaw = configJson["key"] as? String,
            let key = Data(base64Encoded: keyRaw),
            key.count == 32 else {
            print("Could not find 'key' in config file, or it's not base64, or it's not 256 bits")
            exit(EXIT_FAILURE)
        }
        guard let accountId = configJson["accountId"] as? String else {
            print("Could not find 'accountId' in config file")
            exit(EXIT_FAILURE)
        }
        guard let applicationKey = configJson["applicationKey"] as? String else {
            print("Could not find 'applicationKey' in config file")
            exit(EXIT_FAILURE)
        }
        guard let bucketId = configJson["bucketId"] as? String else {
            print("Could not find 'bucketId' in config file")
            exit(EXIT_FAILURE)
        }
        guard let folder = configJson["folder"] as? String else {
            print("Could not find 'folder' in config file")
            exit(EXIT_FAILURE)
        }
        return SyncConfig(key: key, accountId: accountId, applicationKey: applicationKey, bucketId: bucketId, folder: folder)
    }
}
