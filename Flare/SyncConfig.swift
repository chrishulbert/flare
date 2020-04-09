//
//  SyncConfig.swift
//  Flare
//
//  Created by Chris on 25/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

struct SyncConfig {
    let accountId: String
    let applicationKey: String
    let bucketId: String
    let bucketName: String
    let folder: String // Eg "/Users/sam/Flare" - no trailing slash.
}

extension SyncConfig {
    enum Errors: Error {
        case missingConfig
        case couldNotJSONParseConfigFile
        case accountIdMissing
        case applicationKeyMissing
        case bucketIdMissing
        case bucketNameMissing
        case folderMissing
    }
    
    // Load the config from disk.
    static func load() throws -> SyncConfig {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flare")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            print("Please run 'flare configure' first.")
            throw Errors.missingConfig
        }
        
        let configData = try Data(contentsOf: configPath)
        guard let configJson = configData.asJson else {
            throw Errors.couldNotJSONParseConfigFile
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
        guard let bucketName = configJson["bucketName"] as? String else {
            throw Errors.bucketNameMissing
        }
        guard let folder = configJson["folder"] as? String else {
            throw Errors.folderMissing
        }
        return SyncConfig(accountId: accountId,
                          applicationKey: applicationKey,
                          bucketId: bucketId,
                          bucketName: bucketName,
                          folder: (folder as NSString).expandingTildeInPath)
    }
    
    func save() throws {
        let configUrl = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flare")
        let dict: [String: String] = [
            "accountId": accountId,
            "applicationKey": applicationKey,
            "bucketId": bucketId,
            "bucketName": bucketName,
            "folder": folder,
        ]
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configUrl)
    }
}
