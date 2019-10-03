//
//  ListAllFileVersions.swift
//  Flare
//
//  Created by Chris on 3/10/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This wraps ListFileVersions so that it fetches all the files, even if there are >1000 and it needs to iterate.
enum ListAllFileVersions {
    static func send(token: String, apiUrl: String, bucketId: String, prefix: String?, delimiter: String?,
                     startFileName: String? = nil, startFileId: String? = nil, filesSoFar: [ListFileVersionsFile] = [],
                     completion: @escaping (Result<[ListFileVersionsFile], Error>) -> ()) {

        ListFileVersions.send(token: token, apiUrl: apiUrl, bucketId: bucketId, startFileName: nil, startFileId: nil, prefix: prefix, delimiter: delimiter, completion: { result in
            switch result {
            case .success(let response):
                // Do we need to iterate?
                if let nextFileName = response.nextFileName, let nextFileId = response.nextFileId {
                    // Get more files.
                    self.send(token: token,
                              apiUrl: apiUrl,
                              bucketId: bucketId,
                              prefix: prefix,
                              delimiter: delimiter,
                              startFileName: nextFileName,
                              startFileId: nextFileId,
                              filesSoFar: filesSoFar + response.files,
                              completion: completion)
                } else { // No need to iterate any more.
                    completion(.success(filesSoFar + response.files))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
}
