//
//  UploaderWithFolderModifications.swift
//  Flare
//
//  Created by Chris on 29/1/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

let lastModifiedPlaceholderPrefix = ".bzlastmodified"

// TODO if we're uploading 10 files, 10 folders deep, this will touch a .bzlastmodified 100 times. Find some way to combine those.
//TODO if we upload a file with an older last modified date than others in the folder, it'll set the 'last mod' date *back* which isn't good.

/*
 As a workaround to bz not giving us 'lastmodified' on folders, this gives us:
 "files": [
   {
     "accountId": "6f92025453c2",
     "action": "upload",
     "bucketId": "364f3932f0c2656465d30c12",
     "contentLength": 0,
     "contentMd5": "d41d8cd98f00b204e9800998ecf8427e",
     "contentSha1": "da39a3ee5e6b4b0d3255bfef95601890afd80709",
     "contentType": "application/octet-stream",
     "fileId": "4_z364f3932f0c2656465d30c12_f108011e3f2475be4_d20200129_m005729_c000_v0001050_t0051",
     "fileInfo": {
       "src_last_modified_millis": "1580259448082"
     },
     "fileName": "foo/bar/yada.bzlastmodified",
     "uploadTimestamp": 1580259449000
   },
   {
     "accountId": "6f92025453c2",
     "action": "folder",
     "bucketId": "364f3932f0c2656465d30c12",
     "contentLength": 0,
     "contentMd5": null,
     "contentSha1": null,
     "contentType": null,
     "fileId": null,
     "fileInfo": {},
     "fileName": "foo/bar/yada/",
     "uploadTimestamp": 0
   }
 ],
*/
enum UploaderWithFolderModifications {

    /// This wraps Uploader and walks up the tree and touches '.lastmodified' folders to suit.
    /// These are parallel to the actual folder, not children, so it doesn't have to fetch the folders files to know its last mod.
    static func upload(token: String, apiUrl: String, bucketId: String, uploadParams: UploadParams, fileName: String, file: Data, lastModified: Date) throws -> UploadParams {
        var params = try Uploader.upload(token: token, apiUrl: apiUrl, bucketId: bucketId, uploadParams: uploadParams, fileName: fileName, file: file, lastModified: lastModified)
        for folder in folders(fromFile: fileName) {
            params = try Uploader.upload(token: token, apiUrl: apiUrl, bucketId: bucketId, uploadParams: params, fileName: folder + lastModifiedPlaceholderPrefix, file: Data(), lastModified: lastModified)
        }
        return params
    }
        
    /// Converts eg 'foo/bar/blah.txt' to ['foo', 'foo/bar']. Root files return []
    private static func folders(fromFile: String) -> [String] {
        let components = fromFile.components(separatedBy: "/")
        return (1..<components.count).map {
            components.prefix($0).joined(separator: "/")
        }
    }

}
