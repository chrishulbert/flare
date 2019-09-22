//
//  Helpers.swift
//  Flare
//
//  Created by Chris on 4/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation
import CommonCrypto

extension String {    
    var asData: Data {
        return data(using: .utf8) ?? Data()
    }
    var asUrl: URL? {
        return URL(string: self)
    }
}

extension Data {
    var asString: String? {
        return String(data: self, encoding: .utf8)
    }
    var asSha1: [UInt8] {
        return withUnsafeBytes { (urbp: UnsafeRawBufferPointer) in
            var digest: [UInt8] = Array(repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            CC_SHA1(urbp.baseAddress!, CC_LONG(count), &digest)
            return digest
        }
    }
}

extension Collection where Element == UInt8 {
    var asData: Data {
        return Data(self)
    }
    var asHexString: String {
        var str = ""
        for x in self {
            str += String(format: "%02x", x)
        }
        return str
    }
}

extension Date {
    var asBzString: String {
        let millis = timeIntervalSince1970 * 1000
        return String(Int(millis))
    }
}
