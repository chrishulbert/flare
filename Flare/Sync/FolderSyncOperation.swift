//
//  FolderSyncOperation.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This syncs a single folder, and spawns ops for its subfolders.
class FolderSyncOperation: AsyncOperation {
    let syncContext: SyncContext
    let path: String? // Nil for root folder, otherwise something like 'foo/bar/'
    init(syncContext: SyncContext, path: String?) {
        self.syncContext = syncContext
        self.path = path
        super.init()
    }
    
    override func asyncStart() {
        guard let auth = syncContext.authorizeAccountResponse else {
            print("Missing auth token")
            exit(EXIT_FAILURE)
        }
        
        ListAllFileVersions.send(token: auth.authorizationToken, apiUrl: auth.apiUrl, bucketId: syncContext.config.bucketId, prefix: path, delimiter: "/", completion: { [weak self] result in
            switch result {
            case .success(let files):
                self?.handle(files: files)
                
            case .failure(let error):
                print("FolderSyncOperation > ListAllFileVersions error: \(error)")
                exit(EXIT_FAILURE)
            }
        })
    }
    
    /// Handle the returned files listing
    func handle(files: [ListFileVersionsFile]) {
        // Firstly collect a list of the 'remote' state.
        var remoteStates: [String: SyncFileState] = [:]
        for file in files {
            guard let action = file.actionEnum else { continue }
            switch action {
            case .start:
                // In progress, so don't touch anything - this file can be taken care of next time the sync runs.
                print("Ignoring \(file.fileName) because it's an in-progress upload")
                
            case .upload:
                // Skip if we have already encountered this file, because the first version record is the most recent one.
                guard !remoteStates.keys.contains(file.fileName) else { continue }
                remoteStates[file.fileName] = .exists(file.lastModified)
                
            case .hide:
                // Skip if we have already encountered this file, because the first version record is the most recent one.
                guard !remoteStates.keys.contains(file.fileName) else { continue }
                let when = file.uploadTimestamp.asDate // This is the time it was hidden from bz, not the time it was deleted off the local computer, so not ideal but is reasonable.
                remoteStates[file.fileName] = .exists(when)

            case .folder: // Queue syncing subfolders.
                let op = FolderSyncOperation(syncContext: syncContext, path: file.fileName)
                SyncManager.shared.finalOperation.addDependency(op) // Ensure my new op runs before the 'final' one.
                SyncManager.shared.queue.addOperation(op)
            }
        }
        
        // Next collect a list of 'local' state.
        
        // Finally reconcile.
    }
}

enum SyncFileState {
    case exists(Date)
    case deleted(Date)
}

extension ListFileVersionsFile {
    /// Grabs the 'last modified' date if it can, otherwise uses the upload timestamp as a backup.
    var lastModified: Date {
        if let millis = fileInfo["src_last_modified_millis"] as? Int {
            return millis.asDate
        } else {
            return uploadTimestamp.asDate
        }
    }
}

extension Int {
    var asDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(self) / 1000)
    }
}
