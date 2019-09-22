//
//  HideFile.swift
//  Flare
//
//  Created by Chris on 17/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// https://www.backblaze.com/b2/docs/b2_hide_file.html
/// apiUrl is eg "https://apiNNN.backblazeb2.com"
enum HideFile {
    static func send(token: String, apiUrl: String, bucketId: String, fileName: String, completion: @escaping (Result<Void, Error>) -> ()) {
        guard let url = URL(string: apiUrl + "/b2api/v2/b2_hide_file") else {
            completion(.failure(Service.Errors.badApiUrl))
            return
        }
        let body: [String: Any] = [
            "bucketId": bucketId,
            "fileName": fileName,
        ]
        Service.shared.post(url: url, payload: body, token: token, completion: { result in
            switch result {
            case .success:
                completion(.success(()))
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
}
