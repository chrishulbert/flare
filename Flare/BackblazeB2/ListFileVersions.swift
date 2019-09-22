//
//  ListFileVersions.swift
//  Flare
//
//  Created by Chris on 10/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// https://www.backblaze.com/b2/docs/b2_list_file_versions.html
/// maxFileCount shouldn't be over 1000 for pricing reasons.
/// apiUrl is eg "https://apiNNN.backblazeb2.com"
enum ListFileVersions {
    static func send(token: String, apiUrl: String, bucketId: String, startFileName: String?, startFileId: String?, prefix: String?, completion: @escaping (Result<ListFileVersionsResponse, Error>) -> ()) {
        guard let url = URL(string: apiUrl + "/b2api/v2/b2_list_file_versions") else {
            completion(.failure(Service.Errors.badApiUrl))
            return
        }
        var body: [String: Any] = [
            "bucketId": bucketId,
        ]
        if let startFileName = startFileName {
            body["startFileName"] = startFileName
        }
        if let startFileId = startFileId {
            body["startFileId"] = startFileId
        }
        if let prefix = prefix {
            body["prefix"] = prefix
        }

        Service.shared.post(url: url, payload: body, token: token, completion: {result in
            switch result {
            case .success(let json, _):
                let response = ListFileVersionsResponse.from(json: json)
                completion(.success(response))
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
}

struct ListFileVersionsResponse {
    let files: [ListFileVersionsFile]
    let nextFileName: String?
    let nextFileId: String?
}

extension ListFileVersionsResponse {
    static func from(json: [AnyHashable: Any]) -> ListFileVersionsResponse {
        let files: [[AnyHashable: Any]] = json["files"] as? [[AnyHashable: Any]] ?? []
        return ListFileVersionsResponse(files: files.map { ListFileVersionsFile.from(json: $0) },
                                        nextFileName: json["nextFileName"] as? String,
                                        nextFileId: json["nextFileId"] as? String)
    }
}

struct ListFileVersionsFile {
    let accountId: String
    let action: String // start/upload/hide/folder
    let bucketId: String
    let contentLength: Int
    let contentSha1: String?
    let contentType: String?
    let fileId: String?
    let fileInfo: [AnyHashable: Any]
    let fileName: String
    let uploadTimestamp: Int
}

extension ListFileVersionsFile {
    static func from(json: [AnyHashable: Any]) -> ListFileVersionsFile {
        return ListFileVersionsFile(accountId: json["accountId"] as? String ?? "",
                                    action: json["action"] as? String ?? "",
                                    bucketId: json["bucketId"] as? String ?? "",
                                    contentLength: json["contentLength"] as? Int ?? 0,
                                    contentSha1: json["contentSha1"] as? String,
                                    contentType: json["contentType"] as? String,
                                    fileId: json["fileId"] as? String,
                                    fileInfo: json["fileInfo"] as? [AnyHashable : Any] ?? [:],
                                    fileName: json["fileName"] as? String ?? "",
                                    uploadTimestamp: json["uploadTimestamp"] as? Int ?? 0)
    }
}
