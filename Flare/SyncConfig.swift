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
    let folder: String // Eg "/Users/sam/Flare" - no trailing slash.
}

extension SyncConfig {
    enum Errors: Error {
        case couldNotReadConfigFile
        case couldNotJSONParseConfigFile
        case keyMissingOrNot256bitBase64
        case accountIdMissing
        case applicationKeyMissing
        case bucketIdMissing
        case folderMissing
    }
    
    // Load the config from disk.
    static func load() throws -> SyncConfig {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flare")
        guard let configData = try? Data(contentsOf: configPath) else {
            throw Errors.couldNotReadConfigFile
        }
        guard let configJson = configData.asJson else {
            throw Errors.couldNotJSONParseConfigFile
        }
        guard let keyRaw = configJson["key"] as? String,
            let key = Data(base64Encoded: keyRaw),
            key.count == 32 else {
            throw Errors.keyMissingOrNot256bitBase64
        }
        guard let accountId = configJson["accountId"] as? String else {
            throw Errors.accountIdMissing
        }
        guard let applicationKey = configJson["applicationKey"] as? String else {
            throw Errors.applicationKeyMissing
        }
        guard let bucketId = configJson["bucketId"] as? String else {
            throw Errors.bucketIdMissing
        }
        guard let folder = configJson["folder"] as? String else {
            throw Errors.folderMissing
        }
        return SyncConfig(key: key, accountId: accountId, applicationKey: applicationKey, bucketId: bucketId, folder: folder)
    }
}
