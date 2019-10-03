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
            guard let sself = self else { return }
            
            switch result {
            case .success(let files):
                for file in files {
                    guard let action = file.actionEnum else { continue }
                    switch action {
                    case .start:
                        // In progress, so don't touch anything - this file can be taken care of next time the sync runs.
                        print("Ignoring \(file.fileName) because it's an in-progress upload")
                        
                    case .upload:
                        <#code#>
                        
                    case .hide:
                        <#code#>
                        
                    case .folder: // Queue subfolders.
                        let op = FolderSyncOperation(syncContext: sself.syncContext, path: file.fileName)
                        SyncManager.shared.finalOperation.addDependency(op) // Ensure my new op runs before the 'final' one.
                        SyncManager.shared.queue.addOperation(op)
                    }
                }
                
            case .failure(let error):
                print("FolderSyncOperation > ListAllFileVersions error: \(error)")
                exit(EXIT_FAILURE)
            }
        })
    }
}
