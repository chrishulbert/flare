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
    }
    
    /// Path is nil for root folder, otherwise something like 'foo/bar/' with a trailing slash.
    /// Last mod dates are used to 'touch' the folders after all the files are taken into account,
    /// so that next time it runs a sync it can skip this folder. This solves for .DS_Store problem bumping
    /// a folder's date even though no non-hidden files are affected.
    /// If content files are newer than the folder last mod itself (somehow) then it will choose the later date.
    /// Folder last mods can be nil if it's the root folder.
    /// Returns subfolders.
    /// This assumes that the sync context upload params has been set already.
    static func sync(path: String?, localLastModified: Date?, remoteLastModified: Date?, syncContext: SyncContext) throws -> [ListingRecSubfolder] {
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

                // Pull upload params from context.
                guard let uploadParams = syncContext.uploadParams else { throw Errors.missingUploadParams }

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
                // I've tested and verified that this will push the last mod date back if this overwrites a file.
                FileManager.default.createFile(atPath: fileUrl.path,
                                               contents: data,
                                               attributes: [.modificationDate: lastMod])
                
            case .deleteLocal:  // TODO rename to a hidden '.deleted.DATE.ORIGINAL_FILENAME' as a metadata thing, which gets deleted in a month.
                try FileManager.default.removeItem(at: fileUrl)

            case .deleteRemote: // No need to do any 'deletion' metadata with this, because the Bz 'hide' does that for us.
                try HideFile.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, fileName: fileName)

            case .clearLocalDeletedMetadata:
                // TODO Delete '.deleted.*.ORIGINAL_FILENAME' with wildcard in case there are multiple deletions.
                break
            }
        }
        
        // After completing the files, bump the 'last modified' of the folders (if we have a date for either).
        if let path = path,
            let newerLastModified = newerDate(localLastModified: localLastModified,
                                              remoteLastModified: remoteLastModified) {
            if shouldBump(localOrRemote: localLastModified, newerLastMod: newerLastModified) {
                // Bump local.
                // FileManager.setAttributes only affects the given folder, it won't bump the parents' last mod.
                let folderPath = syncContext.config.folder + "/" + path.withTrailingSlashRemoved
                try FileManager.default.setAttributes([.modificationDate: newerLastModified], ofItemAtPath: folderPath)
            }
            if shouldBump(localOrRemote: remoteLastModified, newerLastMod: newerLastModified) {
                // Bump remote.
                guard let uploadParams = syncContext.uploadParams else { throw Errors.missingUploadParams }
                syncContext.uploadParams = try UploaderWithFolderModifications.touch(fromFileOrFolderWithTrailingSlash: path,
                                                                                     lastModified: newerLastModified,
                                                                                     token: auth.authorizationToken,
                                                                                     apiUrl: auth.apiUrl,
                                                                                     bucketId: syncContext.config.bucketId,
                                                                                     uploadParams: uploadParams)
            }
        }
        
        // TODO make it skip files that can't be accessed locally eg they're being saved or something, eg mark them as 'skip this!', deal with them next time around?
        // TODO we *need* the watcher to get an accurate idea of local deletions? But even Dropbox works fine if you quit the app, do stuff, and restart, so it must not rely on watching?
        // TODO Maybe upon local deletion, we 'hide' remotely but don't even do a full sync or anything.
        // TODO for local deletions, think about how to model folder deletes, given that if we simply make `.deleted.DATE.FILENAME` in the same folder it'll be lost. Instead create 'FlareRoot/relevant/folder/here/.deleted.foo.filename ? And for sync deletions, *move* to same file?
        // TODO Or maybe on local deletion, create a .deleted.XFILENAME file which this'll then pick up and remove once synced.
        // TODO When sync deletes a file, move it to a 'deleted' folder eg yyyymmd_filename which gets nuked once >1mo.
        // TODO if another notification comes in for this folder, then once finishing syncing the next file, restart the folder.

        return reconciliation.subfolders
    }

}

/// Returns the newer of the two dates, or nil if both are nil.
func newerDate(localLastModified: Date?, remoteLastModified: Date?) -> Date? {
    if let l = localLastModified, let r = remoteLastModified {
        let m = max(l.timeIntervalSinceReferenceDate, r.timeIntervalSinceReferenceDate)
        return Date(timeIntervalSinceReferenceDate: m)
    } else if let lastModified = localLastModified {
        return lastModified
    } else if let lastModified = remoteLastModified {
        return lastModified
    } else {
        return nil
    }
}

/// Returns true if newerLastMod is >1s newer than localOrRemote. Also true if localOrRemote doesn't have a date.
/// Checks if localOrRemote needs bumping, basically.
func shouldBump(localOrRemote: Date?, newerLastMod: Date) -> Bool {
    guard let localOrRemote = localOrRemote else { return true }
    return newerLastMod.timeIntervalSinceReferenceDate > localOrRemote.timeIntervalSinceReferenceDate+1
}
