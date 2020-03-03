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
/// list_file_names also exists but will not return 'hidden' files.
/// apiUrl is eg "https://apiNNN.backblazeb2.com"
/// delimiter is usually '/' -> https://www.backblaze.com/b2/docs/b2_list_file_names.html
/// To get the root folder (no subfolders' files), specify delimiter=/ only.
/// To get a subfolder, do delimiter=/ prefix=foo/bar/ (use a trailing slash).
/// If you upload then hide: First record is action:hide, second is action:upload
/// Hide record uploadTimestamp": 1568850170000 is the time of hiding.
/// Folders are returned with names like 'photos/cats/'
/// Folders don't have much useful metadata, eg nothing like the date any of its contents were last modified.
///  "accountId": "6f92025453c2",
///  "action": "folder",
///  "bucketId": "364f3932f0c2656465d30c12",
///  "contentLength": 0,
///  "contentMd5": null,
///  "contentSha1": null,
///  "contentType": null,
///  "fileId": null,
///  "fileInfo": {},
///  "fileName": "newfolder/",
///  "uploadTimestamp": 0
/// This will return >1 version of a file. Most recent seems to come last. Which is opposite the above example re upload/hide. So maybe should sort locally.
/// Docs say "by reverse of date/time uploaded for versions of files with the same name".
enum ListFileVersions {
    static func send(token: String, apiUrl: String, bucketId: String, startFileName: String?, startFileId: String?, prefix: String?, delimiter: String?) throws -> ListFileVersionsResponse {
        guard let url = URL(string: apiUrl + "/b2api/v2/b2_list_file_versions") else {
            throw Service.Errors.badApiUrl
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
        if let delimiter = delimiter {
            body["delimiter"] = delimiter
        }

        let (json, _) = try Service.shared.post(url: url, payload: body, token: token)
        return ListFileVersionsResponse.from(json: json)
    }
}

struct ListFileVersionsResponse {
    let files: [ListFileVersionsFile]
    let nextFileName: String? // What to pass in to startFileName for the next search to continue where this one left off, or null if there are no more files.
    let nextFileId: String? // What to pass in to startFileId for the next search to continue where this one left off, or null if there are no more files.
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
    let fileId: String? // Null for folders.
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
    
    var actionEnum: Action? {
        return Action(rawValue: action)
    }
}

enum Action: String {
    case start // "start" means that a large file has been started, but not finished or canceled.
    case upload // "upload" means a file that was uploaded to B2 Cloud Storage.
    case hide // "hide" means a file version marking the file as hidden, so that it will not show up in b2_list_file_names.
    case folder // "folder" is used to indicate a virtual folder when listing files.
}
