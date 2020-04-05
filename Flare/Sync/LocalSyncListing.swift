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
    let files: [String: SyncFileState] // Key = filename including path from root.
    let filesToSkip: Set<String> // Files, for whatever reason, that we should skip. Eg file is locked. These aren't in the 'files' list.
    let subfolders: Set<String>
}

extension LocalSyncListing {
    enum Errors: Error {
        case nilIsDirectory
        case nilFileSize
        case nilContentModificationDate
    }
    
    struct DateAndSize {
        let date: Date
        let size: Int
    }
    
    /// Path=nil for root folder, trailing slash otherwise.
    static func list(path: String?, syncContext: SyncContext) throws -> LocalSyncListing {
        var filesToSkip: Set<String> = []
        var subfolders: Set<String> = []
        let pathURL = syncContext.pathUrl(path: path)
        let contents = try FileManager.default.myContents(ofDirectory: pathURL) // Contents of directory doesn't return hidden files eg .DS_Store, which is helpful.
        let rootUrl = URL(fileURLWithPath: syncContext.config.folder)
        var filesLookup: [String: DateAndSize] = [:] // keys are file names not paths eg 'foo.txt'
        for file in contents {
            let filePathRelativeToRoot = file.absoluteString.deleting(prefix: rootUrl.absoluteString) // For folders, this'll give us a trailing slash which is what we need to suit bz.
            // For files, will be eg: 'foo/bar/yada/blah.txt'
            let resourceValues = try file.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
            guard let isDirectory = resourceValues.isDirectory else { throw Errors.nilIsDirectory }
            guard let contentModificationDate = resourceValues.contentModificationDate else { throw Errors.nilContentModificationDate }

            if isDirectory {
                subfolders.insert(filePathRelativeToRoot)
            } else {
                guard let fileSize = resourceValues.fileSize else { throw Errors.nilFileSize } // Can only get filesize if not a dir.
                if fileSize > maxFileSize {
                    filesToSkip.insert(filePathRelativeToRoot) // Too big. TODO implement 'b2_upload_part' uploads.
                } else {
                    let fileName = file.absoluteString.deleting(prefix: pathURL.absoluteString) // Eg 'foo.txt'
                    filesLookup[fileName] = DateAndSize(date: contentModificationDate, size: fileSize)
                }
            }
        }
        
        // Get what's in the .flare metadata folder.
        let metadataFolder = syncContext.config.folder + "/" + (path ?? "") + localMetadataFolder // No trailing slash.
        let metadataURL = URL(fileURLWithPath: metadataFolder, isDirectory: true)
        let metadataContents = try FileManager.default.myContents(ofDirectory: metadataURL)
        var metadataLookup: [String: Date] = [:] // Key will be eg 'foo.txt'
        for file in metadataContents {
            let resourceValues = try file.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            guard let isDirectory = resourceValues.isDirectory else { throw Errors.nilIsDirectory }
            guard !isDirectory else { continue } // There shouldn't be folders in the metadata folder.
            guard let contentModificationDate = resourceValues.contentModificationDate else { throw Errors.nilContentModificationDate }
            let fileName = file.absoluteString.deleting(prefix: metadataURL.absoluteString) // Eg 'foo.txt'
            metadataLookup[fileName] = contentModificationDate
        }
        
        // Compare vs the .flare subfolder.
        var fileStates: [String: SyncFileState] = [:]
        let allFiles: Set<String> = Set(filesLookup.keys).union(metadataLookup.keys)
        let allFilesSorted = allFiles.sorted() // So it syncs predictably.
        for file in allFilesSorted {
            let pathRelativeToRoot = (path ?? "") + file
            let fileDetails = filesLookup[file]
            let metaDetails = metadataLookup[file]
            if let fileDetails = fileDetails, let _ = metaDetails {
                fileStates[pathRelativeToRoot] = .exists(fileDetails.date, fileDetails.size, nil)
            } else if let fileDetails = fileDetails {
                fileStates[pathRelativeToRoot] = .exists(fileDetails.date, fileDetails.size, nil)
            } else if let metaDetails = metaDetails {
                // Was deleted since last run!
                // Use the 'meta' date as the deleted time, rather than 'now', to give it a better chance of being
                // reconciled as a 'download' rather than a 'delete'.
                fileStates[pathRelativeToRoot] = .deleted(metaDetails)
            }
        }
        
        return LocalSyncListing(files: fileStates, filesToSkip: filesToSkip, subfolders: subfolders)
    }

}
