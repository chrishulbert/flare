//
//  FolderSyncOperation.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This syncs a single folder, and spawns ops for its subfolders.
enum FolderSyncOperation {
    
    enum Errors: Error {
        case missingAuth
        case missingUploadParams
        case nilDate
        case nilIsDirectory
        case nilContentModificationDate
    }
    
    /// Path is nil for root folder, otherwise something like 'foo/bar/' with a trailing slash.
    /// Returns subfolders.
    /// This assumes that the sync context upload params has been set already.
    static func sync(path: String?, syncContext: SyncContext) throws -> [String] {
        guard let auth = syncContext.authorizeAccountResponse else { throw Errors.missingAuth }
        
        // Figure out what needs doing.
        let localState = try LocalSyncListing.list(path: path, syncContext: syncContext)
        let remoteState = try RemoteSyncListing.list(path: path, syncContext: syncContext)
        let reconciliation = ListingReconciliation.reconcile(local: localState, remote: remoteState)
        
        // Now do it.
        let rootUrl = URL(fileURLWithPath: syncContext.config.folder)
        for action in reconciliation.actions {
            print("Action: \(action)")
            let fileName = action.fileName // Eg 'foo/bar/yada.txt'
            let (folder, justFilename) = fileName.folderAndFilename() // eg 'foo/bar' and 'yada.txt'
            let fileUrl = rootUrl.appendingPathComponent(action.fileName)
            switch action {
            case .upload:
                // Get the last mod (grab it fresh rather than store it).
                let values = try fileUrl.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                guard let lastModified = values.contentModificationDate else { throw Errors.nilDate }
                
                // Get the data.
                let data = try Data(contentsOf: fileUrl, options: [])

                // Pull upload params from context.
                guard let uploadParams = syncContext.uploadParams else { throw Errors.missingUploadParams }
                
                // Upload.
                syncContext.uploadParams = try Uploader.upload(token: auth.authorizationToken,
                                                               apiUrl: auth.apiUrl,
                                                               bucketId: syncContext.config.bucketId,
                                                               uploadParams: uploadParams,
                                                               fileName: fileName,
                                                               file: data,
                                                               lastModified: lastModified)
                
            case .download:
                let (data, lastModO) = try DownloadFileByName.send(token: auth.authorizationToken, bucketName: syncContext.config.bucketName, downloadUrl: auth.downloadUrl, fileName: fileName)
                let lastMod = lastModO ?? Date() // Default to today if somehow missing.
                let folder = fileUrl.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: folder,
                                                        withIntermediateDirectories: true,
                                                        attributes: [.modificationDate: lastMod])
                // I've tested and verified that this will push the last mod date back if this overwrites a file.
                FileManager.default.createFile(atPath: fileUrl.path,
                                               contents: data,
                                               attributes: [.modificationDate: lastMod])
                
            case .deleteLocal: // Rename to eg .flare/Deleted/YYYYMMDD.OriginalFilename.txt
                let pathUrl: URL
                if let path = path {
                    pathUrl = rootUrl.appendingPathComponent(path, isDirectory: true)
                } else {
                    pathUrl = rootUrl
                }
                let metaFolder = pathUrl.appendingPathComponent(localMetadataFolder, isDirectory: true)
                let deletionsFolderUrl = metaFolder.appendingPathComponent(deletedMetadataSubfolder, isDirectory: true)
                let ymd = Date().asYYYYMMDD
                let deletedFilename = ymd + "." + justFilename
                let deletedFileUrl = deletionsFolderUrl.appendingPathComponent(deletedFilename, isDirectory: false)
                FileManager.default.createDirectory(at: deletionsFolderUrl, withIntermediateDirectories: true)
                FileManager.default.moveItem(at: fileUrl, to: deletedFileUrl)

            case .deleteRemote: // No need to do any 'deletion' metadata with this, because the Bz 'hide' does that for us.
                try HideFile.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, fileName: fileName)

            case .clearLocalDeletedMetadata:
                // TODO Delete '.deleted.*.ORIGINAL_FILENAME' with wildcard in case there are multiple deletions.
                break
            }
        }
        
        // Now take note of which files exist, so we can know if anything was deleted later.
        // Do a reconcilation against the metadata folder, so we don't unnecessarily make changes.
        // Figure out what *should* be there.
        var metadataThatShouldBeThere: [String: Metadata] = [:] // Keys = eg 'abc.txt'
        for (name, state) in localState.files { // Name is eg 'foo/yada.txt'
            guard case .exists(let lastMod, _, _) = state else { continue }
            let nameSansPath: String // Eg 'foo.txt'
            if let path = path {
                nameSansPath = name.deleting(prefix: path)
            } else { // Root folder.
                nameSansPath = name
            }
            metadataThatShouldBeThere[nameSansPath] = Metadata(date: lastMod, isFolder: false)
        }
        for (name, state) in localState.subfolders {
            guard case .exists = state else { continue }
            let nameSansPath = name.deleting(prefix: path ?? "").withoutTrailingSlash
            metadataThatShouldBeThere[nameSansPath] = Metadata(date: Date(), isFolder: true) // Folder dates don't matter.
        }

        // Figure out what *is* there.
        var metadataThatIsThere: [String: Metadata] = [:] // Keys = eg 'abc.txt'
        let metadataFolder = syncContext.config.folder + "/" + (path ?? "") + localMetadataFolder // No trailing slash.
        let metadataURL = URL(fileURLWithPath: metadataFolder, isDirectory: true)
        let contents = try FileManager.default.myContents(ofDirectory: metadataURL)
        for file in contents {
            let resourceValues = try file.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            guard let isDirectory = resourceValues.isDirectory else { throw Errors.nilIsDirectory }
            let fileName = file.absoluteString.deleting(prefix: metadataURL.absoluteString) // Eg 'foo.txt'
            if isDirectory {
                metadataThatIsThere[fileName.withoutTrailingSlash] = Metadata(date: Date(), isFolder: true) // Folder dates don't matter.
            } else {
                guard let contentModificationDate = resourceValues.contentModificationDate else { throw Errors.nilContentModificationDate }
                metadataThatIsThere[fileName] = Metadata(date: contentModificationDate, isFolder: false)
            }
        }
        
        // Reconcile the metadata folder appropriately.
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: true)
        let allMetadataFilenames: Set<String> = Set(metadataThatShouldBeThere.keys).union(metadataThatIsThere.keys)
        for file in allMetadataFilenames {
            let shouldBeMeta = metadataThatShouldBeThere[file]
            let isMeta = metadataThatIsThere[file]
            let fileURL = metadataURL.appendingPathComponent(file)
            if let shouldBeMeta = shouldBeMeta, let isMeta = isMeta {
                if shouldBeMeta.isFolder != isMeta.isFolder { // Changed from folder to file or vice versa!
                    try FileManager.default.removeItem(at: fileURL)
                    if shouldBeMeta.isFolder {
                        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
                    } else {
                        FileManager.default.createFile(atPath: fileURL.path,
                                                       contents: Data(), // Empty file.
                                                       attributes: [.modificationDate: shouldBeMeta.date])
                    }
                } else if !shouldBeMeta.isFolder && !isMeta.isFolder && abs(shouldBeMeta.date.timeIntervalSince(isMeta.date)) > 2 { // Date has changed.
                    try FileManager.default.setAttributes([.modificationDate: shouldBeMeta],
                                                          ofItemAtPath: fileURL.path)
                } else {
                    // All good!
                }
            } else if let shouldBeMeta = shouldBeMeta { // Should be there but isn't, so add it.
                if shouldBeMeta.isFolder {
                    try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
                } else {
                    FileManager.default.createFile(atPath: fileURL.path,
                                                   contents: Data(), // Empty file.
                                                   attributes: [.modificationDate: shouldBeMeta.date])
                }
            } else if let _ = isMeta { // Is in the metadata folder, but shouldn't be, so remove it.
                try FileManager.default.removeItem(at: fileURL)
            }
        }
        
        // Remove too-old deleted files.
        metadataURL.appendPathComponent(<#T##pathComponent: String##String#>, isDirectory: <#T##Bool#>)
        

        return reconciliation.subfolders
    }

}
