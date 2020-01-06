//
//  GetUploadUrl.swift
//  Flare
//
//  Created by Chris on 22/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// https://www.backblaze.com/b2/docs/b2_get_upload_url.html
/// apiUrl is eg "https://apiNNN.backblazeb2.com"
/// An uploadUrl and upload authorizationToken are valid for 24 hours or until the endpoint
/// rejects an upload, see b2_upload_file.
/// You can upload as many files to this URL as you need.
/// To achieve faster upload speeds, request multiple uploadUrls and upload your files to these different
/// endpoints in parallel.
enum GetUploadUrl {
    static func send(token: String, apiUrl: String, bucketId: String) throws -> UploadParams {
        guard let url = URL(string: apiUrl + "/b2api/v2/b2_get_upload_url") else {
            throw Service.Errors.badApiUrl
        }

        let (json, _) = try Service.shared.post(url: url, payload: [ "bucketId": bucketId ], token: token)
        guard let response = UploadParams.from(json: json) else {
            throw Service.Errors.invalidResponse
        }
        return response
    }
}

struct UploadParams {
    let uploadUrl: URL
    let authorizationToken: String // Special token just for upload calls.
}

extension UploadParams {
    static func from(json: [AnyHashable: Any]) -> UploadParams? {
        guard let u = (json["uploadUrl"] as? String)?.asUrl else { return nil }
        guard let a = json["authorizationToken"] as? String else { return nil }
        return UploadParams(uploadUrl: u, authorizationToken: a)
    }
}
