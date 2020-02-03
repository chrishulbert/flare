//
//  GetFileInfo.swift
//  Flare
//
//  Created by Chris on 2/2/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

/// https://www.backblaze.com/b2/docs/b2_get_file_info.html
/// apiUrl is eg "https://apiNNN.backblazeb2.com"
/// An uploadUrl and upload authorizationToken are valid for 24 hours or until the endpoint
/// fileId is returned by an file listing, eg "4_z364f3932f0c2656465d30c12_f1096bdf6856a5e58_d20200202_m095223_c000_v0001050_t0005" and is per-version.
/// Returns nil if file isn't found.
enum GetFileInfo {
    static func send(token: String, apiUrl: String, fileId: String) throws -> ListFileVersionsFile? {
        guard let url = URL(string: apiUrl + "/b2api/v2/b2_get_file_info") else {
            throw Service.Errors.badApiUrl
        }

        do {
            let (json, _) = try Service.shared.post(url: url, payload: [ "fileId": fileId ], token: token)
            return ListFileVersionsFile.from(json: json)
        } catch (Service.Errors.not200(404, _, _)) {
            return nil
        }
    }
}
