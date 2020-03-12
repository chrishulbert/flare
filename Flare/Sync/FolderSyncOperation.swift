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
        case nilDate
    }
    
    /// Path is nil for root folder, otherwise something like 'foo/bar/' with a trailing slash.
    /// Returns subfolders.
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
            let fileName = action.fileName
            let fileUrl = rootUrl.appendingPathComponent(action.fileName)
            switch action {
            case .upload:
                // Get the last mod (grab it fresh rather than store it).
                let values = try fileUrl.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                guard let lastModified = values.contentModificationDate else { throw Errors.nilDate }
                
                // Get the data.
                let data = try Data(contentsOf: fileUrl, options: [])

                // Get upload params if necessary.
                let uploadParams: UploadParams
                if let up = syncContext.uploadParams {
                    uploadParams = up
                } else {
                    uploadParams = try GetUploadUrl.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId)
                }

                // Upload.
                syncContext.uploadParams = try UploaderWithFolderModifications.upload(token: auth.authorizationToken,
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
                FileManager.default.createFile(atPath: fileUrl.path,
                                               contents: data,
                                               attributes: [.modificationDate: lastMod])
                // TODO it 'touches' the date of the folder
                // TODO look into why grandparent folders don't get dates touched. Or do they, and finder is just slow to update? Check in terminal.
                // TODO will the above be a big problem?
                // TODO why is it downloading files that match?
                
            case .deleteLocal:  // TODO rename to a hidden '.deleted.DATE.ORIGINAL_FILENAME' as a metadata thing, which gets deleted in a month.
                try FileManager.default.removeItem(at: fileUrl)

            case .deleteRemote: // No need to do any 'deletion' metadata with this, because the Bz 'hide' does that for us.
                try HideFile.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, fileName: fileName)

            case .clearLocalDeletedMetadata:
                // TODO Delete '.deleted.*.ORIGINAL_FILENAME' with wildcard in case there are multiple deletions.
                break
                
            }
        }
        
        // TODO make it skip files that can't be accessed locally eg they're being saved or something, eg mark them as 'skip this!', deal with them next time around?
        // TODO we *need* the watcher to get an accurate idea of local deletions? But even Dropbox works fine if you quit the app, do stuff, and restart, so it must not rely on watching?
        // TODO Maybe upon local deletion, we 'hide' remotely but don't even do a full sync or anything.
        // TODO for local deletions, think about how to model folder deletes, given that if we simply make `.deleted.DATE.FILENAME` in the same folder it'll be lost. Instead create 'FlareRoot/relevant/folder/here/.deleted.foo.filename ? And for sync deletions, *move* to same file?
        // TODO Or maybe on local deletion, create a .deleted.XFILENAME file which this'll then pick up and remove once synced.
        // TODO When sync deletes a file, move it to a 'deleted' folder eg yyyymmd_filename which gets nuked once >1mo.
        // TODO if another notification comes in for this folder, then once finishing syncing the next file, restart the folder.

        return Array(reconciliation.subfolders).sorted()
    }

}
