//
//  Helpers.swift
//  Flare
//
//  Created by Chris on 4/9/19.
//  Copyright © 2019 Splinter. All rights reserved.
//

import Foundation

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
}
