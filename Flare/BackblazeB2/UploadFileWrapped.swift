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
    static func send(token: String, uploadParams: UploadParams, fileName: String, file: Data, lastModified: Date) throws -> UploadResult {
        do {
            try UploadFile.send(token: uploadParams.authorizationToken, uploadUrl: uploadParams.uploadUrl, fileName: fileName, file: file, lastModified: lastModified)
            return .success
        } catch (let error) {
            if let res = UploadResult.from(error: error) {
                return res
            } else {
                throw error
            }
        }
    }
}

enum UploadResult {
    case success
    case needNewUploadUrl(Error) // There was an issue with the backblaze pod you tried to use.
}

extension UploadResult {
    /// Parses an error to determine if it's one of the errors that Backblaze recommends getting a new upload url for.
    /// https://www.backblaze.com/b2/docs/uploading.html
    /// Returns nil if plain error.
    static func from(error: Error) -> UploadResult? {
        let nse = error as NSError
        if nse.code == NSURLErrorCannotConnectToHost || nse.code == NSURLErrorTimedOut {
            return .needNewUploadUrl(error)
        }
        switch error {
        case Service.Errors.not200(401, "expired_auth_token", _):
            return .needNewUploadUrl(error)
        case Service.Errors.not200(408, _, _):
            return .needNewUploadUrl(error)
        case Service.Errors.not200(let code, _, _):
            if 500 <= code && code <= 599 {
                return .needNewUploadUrl(error)
            }
        default:
            break
        }
        // TODO detect 'broken pipe'
        return nil
    }
}
