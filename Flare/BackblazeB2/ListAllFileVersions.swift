//
//  ListAllFileVersions.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This wraps ListFileVersions so that it fetches all the files, even if there are >1000 and it needs to iterate.
/// Use a trailing slash for 'prefix' if you want a subfolder.
enum ListAllFileVersions {
    static func send(token: String, apiUrl: String, bucketId: String, prefix: String?, delimiter: String?,
                     startFileName: String? = nil, startFileId: String? = nil, filesSoFar: [ListFileVersionsFile] = []) throws -> [ListFileVersionsFile] {

        let response = try ListFileVersions.send(token: token, apiUrl: apiUrl, bucketId: bucketId, startFileName: nil, startFileId: nil, prefix: prefix, delimiter: delimiter)
        
        // Do we need to iterate?
        if let nextFileName = response.nextFileName, let nextFileId = response.nextFileId {
            // Get more files.
            return try send(token: token,
                      apiUrl: apiUrl,
                      bucketId: bucketId,
                      prefix: prefix,
                      delimiter: delimiter,
                      startFileName: nextFileName,
                      startFileId: nextFileId,
                      filesSoFar: filesSoFar + response.files)
        } else { // No need to iterate any more.
            return filesSoFar + response.files
        }
    }
}
