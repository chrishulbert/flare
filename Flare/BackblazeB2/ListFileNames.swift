//
//  ListFileNames.swift
//  Flare
//
//  Created by Chris on 3/2/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

/// https://www.backblaze.com/b2/docs/b2_list_file_names.html
/// This is different to ListFileVersions in that it should only return one entry per file.
enum ListFileNames {
    static func send(token: String, apiUrl: String, bucketId: String, startFileName: String?, maxFileCount: Int?, prefix: String?, delimiter: String?) throws -> ListFileVersionsResponse {
        guard let url = URL(string: apiUrl + "/b2api/v2/b2_list_file_names") else {
            throw Service.Errors.badApiUrl
        }
        var body: [String: Any] = [
            "bucketId": bucketId,
        ]
        if let startFileName = startFileName {
            body["startFileName"] = startFileName
        }
        if let maxFileCount = maxFileCount {
            body["maxFileCount"] = maxFileCount
        }
        if let prefix = prefix {
            body["prefix"] = prefix
        }
        if let delimiter = delimiter {
            body["delimiter"] = delimiter
        }
        let (json, _) = try Service.shared.post(url: url, payload: body, token: token)
        return ListFileVersionsResponse.from(json: json)
    }
}
