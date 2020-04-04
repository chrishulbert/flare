//
//  ListAllLatestFileVersions.swift
//  Flare
//
//  Created by Chris on 3/3/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

/// This wraps ListAllFileVersions so that it only returns the 'latest' version for each file.
enum ListAllLatestFileVersions {
    static func send(token: String, apiUrl: String, bucketId: String, prefix: String?, delimiter: String?) throws -> [ListFileVersionsFile] {
        let files = try ListAllFileVersions.send(token: token, apiUrl: apiUrl, bucketId: bucketId, prefix: prefix, delimiter: delimiter)
        
        // For speed, only walk through the files array once, and use a hash map to compare.
        var fileNamesToDetails: [String: ListFileVersionsFile] = [:]
        for file in files {
            if let otherFile = fileNamesToDetails[file.fileName] {
                // Figure out which is the newer file record and keep that one.
                if file.uploadTimestamp > otherFile.uploadTimestamp {
                    fileNamesToDetails[file.fileName] = file
                }
            } else { // This filename doesn't exist, so no comparison necessary.
                fileNamesToDetails[file.fileName] = file
            }
        }
        
        return Array(fileNamesToDetails.values)
    }
}

extension ListFileVersionsFile {
    /// Copy self, but change the dates to use the dates from the other record.
    func file(withDatesFrom other: ListFileVersionsFile) -> ListFileVersionsFile {
        var mutatedInfo = fileInfo
        if let otherLastMod = other.fileInfo[fileInfoLastModifiedKey] {
            mutatedInfo[fileInfoLastModifiedKey] = otherLastMod
        }
        return ListFileVersionsFile(accountId: accountId,
                                    action: action,
                                    bucketId: bucketId,
                                    contentLength: contentLength,
                                    contentSha1: contentSha1,
                                    contentType: contentType,
                                    fileId: fileId,
                                    fileInfo: mutatedInfo,
                                    fileName: fileName,
                                    uploadTimestamp: other.uploadTimestamp)
    }
}
