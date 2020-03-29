//
//  LocalSyncListing.swift
//  Flare
//
//  Created by Chris on 6/3/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

let maxFileSize = 10*1024*1024 // Don't attempt to sync anything bigger than this.

/// This lets you get a local listing of files for sync purposes.
struct LocalSyncListing {
    let files: [String: SyncFileState] // Key = filename.
    let filesToSkip: Set<String> // Files, for whatever reason, that we should skip. Eg file is locked.
    let subfolders: [String: Date] // Value = last modified date.
}

extension LocalSyncListing {
    enum Errors: Error {
        case nilIsDirectory
        case nilFileSize
        case nilContentModificationDate
    }
    
    /// Path=nil for root folder.
    static func list(path: String?, syncContext: SyncContext) throws -> LocalSyncListing {
        var fileStates: [String: SyncFileState] = [:]
        var filesToSkip: Set<String> = []
        var subfolders: [String: Date] = [:]
        let contents = try FileManager.default.myContents(ofDirectory: syncContext.pathUrl(path: path)) // Contents of directory doesn't return hidden files eg .DS_Store, which is helpful.
        let rootUrl = URL(fileURLWithPath: syncContext.config.folder)
        for file in contents {
            let filePathRelativeToRoot = file.absoluteString.deleting(prefix: rootUrl.absoluteString) // For folders, this'll give us a trailing slash which is what we need to suit bz.
            let resourceValues = try file.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
            guard let isDirectory = resourceValues.isDirectory else { throw Errors.nilIsDirectory }
            guard let contentModificationDate = resourceValues.contentModificationDate else { throw Errors.nilContentModificationDate }

            if isDirectory { // Add to a set of subfolders, along with local subfolders, so we don't add 2 operations for one folder.
                subfolders[filePathRelativeToRoot] = contentModificationDate
            } else {
                guard let fileSize = resourceValues.fileSize else { throw Errors.nilFileSize } // Can only get filesize if not a dir.
                if fileSize > maxFileSize {
                    filesToSkip.insert(filePathRelativeToRoot) // Too big. TODO implement 'b2_upload_part' uploads.
                } else {
                    fileStates[filePathRelativeToRoot] = .exists(contentModificationDate, fileSize, nil)
                }
            }
        }
        
        // TODO figure out how to model local deletions. Maybe just make a metadata folder or something. Or an agent.
        
        return LocalSyncListing(files: fileStates, filesToSkip: filesToSkip, subfolders: subfolders)
    }

}
