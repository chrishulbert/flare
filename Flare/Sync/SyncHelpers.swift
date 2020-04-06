//
//  SyncHelpers.swift
//  Flare
//
//  Created by Chris on 6/1/20.
//  Copyright © 2020 Splinter. All rights reserved.
//
//  Various helpers go in here.

import Foundation

let fileInfoLastModifiedKey = "src_last_modified_millis"
let bzHeaderLastModified = "X-Bz-Info-" + fileInfoLastModifiedKey
let bzHeaderLastModifiedResponse = "x-bz-info-" + fileInfoLastModifiedKey
let localMetadataFolder = ".flare" // Contains the dates of each folder.

extension SyncContext {
    func pathUrl(path: String?) -> URL {
        let root = URL(fileURLWithPath: config.folder)
        if let path = path {
            return URL(fileURLWithPath: path, relativeTo: root)
        } else {
            return root
        }
    }
}

enum SyncFileState {
    case exists(Date, Int, String?) // modified, size in bytes, sha1 for remote only.
    case deleted(Date)
    case missing
}

extension ListFileVersionsFile {
    /// Grabs the 'last modified' date if it can (which is the time we specified a file was modified), otherwise uses the upload timestamp as a backup (which might be later).
    var lastModified: Date {
        if let millis = fileInfo[fileInfoLastModifiedKey] as? Int {
            return millis.asDate
        } else if let millis = (fileInfo[fileInfoLastModifiedKey] as? String)?.asInt {
            return millis.asDate
        } else {
            return uploadTimestamp.asDate
        }
    }
}

extension Int {
    var asDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(self) / 1000)
    }
}

extension String {
    var asInt: Int? {
        return Int(self)
    }
    
    func deleting(prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
    
    var withoutTrailingSlash: String {
        guard hasSuffix("/") else { return self }
        return String(dropLast(1))        
    }
}

extension FileManager {
    /// Gets the contents of a dir, gracefully returning [] if the dir doesn't exist, thus needs to be synced down.
    func myContents(ofDirectory: URL) throws -> [URL] {
        do {
            return try contentsOfDirectory(at: ofDirectory,
                                           includingPropertiesForKeys: [URLResourceKey.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
                                           options: .skipsHiddenFiles)
        } catch (let error) {
            if (error as NSError).code == 260 { // No such directory, which is fine, just needs to be synced down.
                return []
            } else {
                throw error // Unknown error we shouldn't ignore.
            }
        }
    }
}

enum SyncAction: Equatable {
    case upload(String, Int) // Int = file size.
    case download(String, Int)
    case deleteLocal(String)
    case deleteRemote(String)
    case clearLocalDeletedMetadata(String) // Delete '.deleted.*.ORIGINAL_FILENAME' with wildcard in case there are multiple deletions.
}

extension SyncAction {
    var fileName: String {
        switch self {
        case .upload(let f, _):
            return f
        case .download(let f, _):
            return f
        case .deleteLocal(let f):
            return f
        case .deleteRemote(let f):
            return f
        case .clearLocalDeletedMetadata(let f):
            return f
        }
    }
}

extension SyncAction: Comparable {
    // Order the actions so the fastest things happen first.
    var order: Int {
        switch self {
        case .deleteLocal:
            return 1
        case .clearLocalDeletedMetadata:
            return 2
        case .deleteRemote:
            return 3
        case .download:
            return 4
        case .upload:
            return 5
        }
    }
    
    var size: Int {
        switch self {
        case .deleteLocal, .clearLocalDeletedMetadata, .deleteRemote:
            return 0
        case .download(_, let size):
            return size
        case .upload(_, let size):
            return size
        }
    }
    
    static func < (lhs: SyncAction, rhs: SyncAction) -> Bool {
        let orderL = lhs.order
        let orderR = rhs.order
        if orderL == orderR { // Same operation precedence, so compare sizes.
            return lhs.size < rhs.size
        } else {
            return orderL < orderR
        }
    }
}

extension Data {
    var asJson: [AnyHashable: Any]? {
        let json = try? JSONSerialization.jsonObject(with: self, options: [])
        return json as? [AnyHashable: Any]
    }
}
