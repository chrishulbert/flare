//
//  ListAllLatestFileVersions.swift
//  Flare
//
//  Created by Chris on 3/3/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

/// This wraps ListAllFileVersions so that it only returns the 'latest' version for each file.
/// Also integrates folders with their lastModified versions to get a date.
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
        
        // TODO handle folders that have no .bzlastmodified somehow, eg make their dates optional.
        
        // Find ones (eg folders) with matching last modified entries, and apply the dates across.
        // This is a workaround for Bz not having folder modification dates.
        var lastModFilesToRemove: [String] = []
        for (fileName, details) in fileNamesToDetails {
            guard fileName.hasSuffix(lastModifiedPlaceholderPrefix) else { continue }
            lastModFilesToRemove.append(fileName)
            
            // Convert from "foo.bzlastmodified" to "foo/" (because bz folders have trailing slashes whereas files don't, because reasons).
            var sourceFolder = fileName
            sourceFolder.removeLast(lastModifiedPlaceholderPrefix.count)
            sourceFolder.append("/")
            
            if let sourceFolderDetails = fileNamesToDetails[sourceFolder] {
                fileNamesToDetails[sourceFolder] = sourceFolderDetails.file(withDatesFrom: details)
            } else { // Add the folder. This edge case happens when a folder is empty.
                fileNamesToDetails[sourceFolder] = .folder(withDatesFrom: details, fileName: sourceFolder)
            }
        }
        
        // Remove last modified entries.
        for file in lastModFilesToRemove {
            fileNamesToDetails.removeValue(forKey: file)
        }
        
        return Array(fileNamesToDetails.values)
    }
}

extension String {
    var withTrailingSlashRemoved: String {
        if self.hasSuffix("/") {
            var temp = self
            _ = temp.popLast()
            return temp
        } else {
            return self
        }
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
    
    /// Creates a folder record using another's dates.
    static func folder(withDatesFrom other: ListFileVersionsFile, fileName: String) -> ListFileVersionsFile {
        return ListFileVersionsFile(accountId: "",
                                    action: Action.folder.rawValue,
                                    bucketId: "",
                                    contentLength: 0,
                                    contentSha1: nil,
                                    contentType: nil,
                                    fileId: nil,
                                    fileInfo: other.fileInfo,
                                    fileName: fileName,
                                    uploadTimestamp: other.uploadTimestamp)
    }
}
