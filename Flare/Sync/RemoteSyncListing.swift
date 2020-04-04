//
//  RemoteSyncListing.swift
//  Flare
//
//  Created by Chris on 6/3/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

/// This lets you get a remote listing of files for sync purposes.
struct RemoteSyncListing {
    let files: [String: SyncFileState] // Key = filename.
    let filesToSkip: Set<String> // Files, for whatever reason, that we should skip. Eg half-uploaded.
    let subfolders: Set<String>
}

extension RemoteSyncListing {
    enum Errors: Error {
        case nilAuthToken
    }
    
    /// Path=nil for root folder.
    static func list(path: String?, syncContext: SyncContext) throws -> RemoteSyncListing {
        guard let auth = syncContext.authorizeAccountResponse else {
            throw Errors.nilAuthToken
        }
        
        // Hit the API.
        let files = try ListAllLatestFileVersions.send(token: auth.authorizationToken,
                                                       apiUrl: auth.apiUrl,
                                                       bucketId: syncContext.config.bucketId,
                                                       prefix: path,
                                                       delimiter: "/")
        
        // Figure out what to make of the results.
        var fileStates: [String: SyncFileState] = [:]
        var filesToSkip: Set<String> = []
        var subfolders: Set<String> = []
        for file in files {
            guard let action = file.actionEnum else { continue }
            guard !file.fileName.isHiddenFile else { continue } // Skip hidden files, to match myContents(ofDirectory which also skips hidden files.
            switch action {
            case .start:
                // In progress, so don't touch anything - this file can be taken care of next time the sync runs.
                filesToSkip.insert(file.fileName)
                
            case .upload:
                fileStates[file.fileName] = .exists(file.lastModified, file.contentLength, file.contentSha1)
                
            case .hide:
                let when = file.uploadTimestamp.asDate // This is the time it was hidden from bz, not the time it was deleted off the local computer, so not ideal but is reasonable.
                fileStates[file.fileName] = .deleted(when)

            case .folder:
                subfolders.insert(file.fileName)
            }
        }
        
        return RemoteSyncListing(files: fileStates, filesToSkip: filesToSkip, subfolders: subfolders)
    }

}

extension String {
    /// Checks if the last component is hidden (starts with .), eg:
    /// a/b/c/d/.bzEmpty - would be hidden.
    var isHiddenFile: Bool {
        let comps = components(separatedBy: "/")
        guard let last = comps.last else { return false }
        return last.hasPrefix(".")
    }
}
