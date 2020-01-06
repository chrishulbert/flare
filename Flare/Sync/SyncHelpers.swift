//
//  SyncHelpers.swift
//  Flare
//
//  Created by Chris on 6/1/20.
//  Copyright © 2020 Splinter. All rights reserved.
//
//  Various helpers go in here.

import Foundation

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
    /// Grabs the 'last modified' date if it can, otherwise uses the upload timestamp as a backup.
    var lastModified: Date {
        if let millis = fileInfo["src_last_modified_millis"] as? Int {
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
    func deleting(prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
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

enum SyncAction {
    case upload(String)
    case download(String)
    case deleteLocal(String) // TODO rename to a hidden '.deleted.DATE.ORIGINAL_FILENAME' as a metadata thing, which gets deleted in a month.
    case deleteRemote(String)
    case clearLocalDeletedMetadata(String) // Delete '.deleted.*.ORIGINAL_FILENAME' with wildcard in case there are multiple deletions.
    case clearRemoteDeletedMetadata(String)
}

extension Data {
    var asJson: [AnyHashable: Any]? {
        let json = try? JSONSerialization.jsonObject(with: self, options: [])
        return json as? [AnyHashable: Any]
    }
}
