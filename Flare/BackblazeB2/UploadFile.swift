//
//  UploadFile.swift
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
enum UploadFile {
    static func send(token: String, uploadUrl: URL, fileName: String, file: Data, lastModified: Date, completion: @escaping (Result<URL, Error>) -> ()) {
        let percentName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let headers: [String: String] = [
            "X-Bz-File-Name": percentName,
            "Content-Type": "b2/x-auto",
            "Content-Length": String(file.count),
            "X-Bz-Content-Sha1": file.asSha1.asHexString,
            "X-Bz-Info-src_last_modified_millis": lastModified.asBzString
            
        ]
        Service.shared.postOrPutRaw(httpMethod: "POST", url: uploadUrl, body: file, headers: headers, token: token, completion: { result in
            switch result {
            case .success(let json, _):
                guard let uploadUrl = (json["uploadUrl"] as? String)?.asUrl else {
                    completion(.failure(Service.Errors.invalidResponse))
                    return
                }
                completion(.success(uploadUrl))
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
}
