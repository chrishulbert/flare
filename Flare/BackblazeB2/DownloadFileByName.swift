//
//  DownloadFileByName.swift
//  Flare
//
//  Created by Chris on 9/3/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

/// https://www.backblaze.com/b2/docs/b2_download_file_by_name.html
enum DownloadFileByName {
    enum Errors: Error {
        case badUrl
    }
    /// Returns data, last modified date.
    static func send(token: String, bucketName: String, downloadUrl: String, fileName: String) throws -> (Data, Date?) {
        let urlString = downloadUrl + "/file/" + bucketName + "/" + fileName
        guard let url = URL(string: urlString) else { throw Errors.badUrl }
        let (data, response) = try Service.shared.get(url: url, token: token)
        let lastModStr = response.allHeaderFields[bzHeaderLastModifiedResponse] as? String
        let lastMod = lastModStr?.asInt?.asDate
        return (data, lastMod)
    }
}
