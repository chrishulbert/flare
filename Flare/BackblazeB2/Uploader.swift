//
//  Uploader.swift
//  Flare
//
//  Created by Chris on 23/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

/// https://www.backblaze.com/b2/docs/uploading.html
/// This is responsible for wrapping GetUploadUrl and UploadFileWrapped so that it'll retry 5 times until it finds a non-busy Backblaze pod.
enum Uploader {
    /// You should pass in an uploadUrl from a previous call to GetUploadUrl, so we can reuse it until that pod is busy.
    /// Successful completion will give you the upload url to reuse (or the url it re-fetched on a retry).
    static func send(token: String, apiUrl: String, bucketId: String, uploadUrl: URL, fileName: String, file: Data, lastModified: Date, completion: @escaping (Result<URL, Error>) -> ()) {
        UploadFileWrapped.send(token: token, uploadUrl: uploadUrl, fileName: fileName, file: file, lastModified: lastModified, completion: { result in
            switch result {
            case .success:
                completion(.success(uploadUrl))

            case .needNewUploadUrl:
                self.getUploadUrlThenUpload(failures: 1, token: token, apiUrl: apiUrl, bucketId: bucketId, fileName: fileName, file: file, lastModified: lastModified, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    /// This recurses until failures is too high.
    private static func getUploadUrlThenUpload(failures: Int, token: String, apiUrl: String, bucketId: String, fileName: String, file: Data, lastModified: Date, completion: @escaping (Result<URL, Error>) -> ()) {
        GetUploadUrl.send(token: token, apiUrl: apiUrl, bucketId: bucketId, completion: { result in
            switch result {
            case .success(let uploadUrl):
                UploadFileWrapped.send(token: token, uploadUrl: uploadUrl, fileName: fileName, file: file, lastModified: lastModified, completion: { result in
                    switch result {
                    case .success:
                        completion(.success(uploadUrl)) // Return the newly-fetched uploadUrl so it can be reused until its pod gets busy.

                    case .needNewUploadUrl(let error): // Backblaze pod is probably busy.
                        if failures < 5 { // Retry another time.
                            self.getUploadUrlThenUpload(failures: failures + 1, token: token, apiUrl: apiUrl, bucketId: bucketId, fileName: fileName, file: file, lastModified: lastModified, completion: completion)
                        } else {
                            completion(.failure(error)) // Give up, too many times.
                        }

                    case .failure(let error): // Non-recoverable error.
                        completion(.failure(error))
                    }
                })
                
            case .failure(let error):
                completion(.failure(error)) // Couldn't get an upload url.
            }
        })
    }
    
}
