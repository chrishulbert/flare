//
//  Scheduler.swift
//  Flare
//
//  Created by Chris on 9/4/20.
//  Copyright © 2020 Splinter. All rights reserved.
//

import Foundation

fileprivate let plistTemplate = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>au.com.splinter.flare</string>
        <key>Program</key>
        <string>$PROGRAM</string>
        <key>ProgramArguments</key>
        <array>
            <string>$PROGRAM</string>
            <string>sync</string>
        </array>
        <key>StartCalendarInterval</key>
        <dict>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </dict>
</plist>
"""
fileprivate let plistPath = "~/Library/LaunchAgents/au.com.splinter.flare.plist"

enum Schedule {
    enum Errors: Error {
        case missingExecutablePath
    }
    
    static func install() throws {
        print("Creating: " + plistPath)
        guard let executablePath = Bundle.main.executablePath else { throw Errors.missingExecutablePath }
        let plist = plistTemplate.replacingOccurrences(of: "$PROGRAM", with: executablePath)
        let path = (plistPath as NSString).expandingTildeInPath
        try plist.write(toFile: path, atomically: false, encoding: .utf8)
        
        print("Loading:")
        print(launchctlLoad(plistPath: path))
        
        print("Done, it should sync every hour on the hour now.")
        print("You can test with 'launchctl list | grep flare'")
    }
}

func launchctlLoad(plistPath: String) -> String {
    let task = Process()
    task.launchPath = "/bin/launchctl"
    task.arguments = ["load", plistPath]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
