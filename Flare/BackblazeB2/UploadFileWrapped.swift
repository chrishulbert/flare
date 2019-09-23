//
//  UploadFileWrapped.swift
//  Flare
//
//  Created by Chris on 23/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// This does an upload, and figures out if any error means 'retry another Backblaze pod' or 'legitimate error'.
enum UploadFileWrapped {
    static func send(token: String, uploadUrl: URL, fileName: String, file: Data, lastModified: Date, completion: @escaping (UploadResult) -> ()) {
        UploadFile.send(token: token, uploadUrl: uploadUrl, fileName: fileName, file: file, lastModified: lastModified, completion: { result in
            switch result {
            case .success:
                completion(.success)
                
            case .failure(let error):
                completion(.from(error: error))
            }
        })
    }
}

enum UploadResult {
    case success
    case failure(Error)
    case needNewUploadUrl // There was an issue with the backblaze pod you tried to use.
}

extension UploadResult {
    /// Parses an error to determine if it's one of the errors that Backblaze recommends getting a new upload url for.
    /// https://www.backblaze.com/b2/docs/uploading.html
    static func from(error: Error) -> UploadResult {
        let nse = error as NSError
        if nse.code == NSURLErrorCannotConnectToHost || nse.code == NSURLErrorTimedOut {
            return .needNewUploadUrl
        }
        switch error {
        case Service.Errors.not200(401, "expired_auth_token", _):
            return .needNewUploadUrl
        case Service.Errors.not200(408, _, _):
            return .needNewUploadUrl
        case Service.Errors.not200(let code, _, _):
            if 500 <= code && code <= 599 {
                return .needNewUploadUrl
            }
        default:
            break
        }
        // TODO detect 'broken pipe'
        return .failure(error)
    }
}
