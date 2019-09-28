////
////  Watcher.swift
////  Flare
////
////  Created by Chris on 28/9/19.
////  Copyright © 2019 Splinter. All rights reserved.
////
//
//import Foundation
//import CoreServices
//
//// With help from https://github.com/njdehoog/Witness/blob/master/Sources/Witness/EventStream.swift
//// https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html#//apple_ref/doc/uid/TP40005289-CH4-SW4
//class Watcher {
//    
//    let stream: FSEventStreamRef
//    
//    private init(stream: FSEventStreamRef) {
//        self.stream = stream
//    }
//    
//    deinit {
//        FSEventStreamStop(stream)
//        FSEventStreamInvalidate(stream)
//        FSEventStreamRelease(stream)
//    }
//    
//    static func watch(path: String) -> Watcher? {
////        kFSEventStreamEventIdSinceNow as FSEventStreamEventId
//        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes + kFSEventStreamCreateFlagIgnoreSelf + kFSEventStreamCreateFlagFileEvents)
//        
//        func callback(stream: ConstFSEventStreamRef, clientCallbackInfo: UnsafeMutableRawPointer?, numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIDs: UnsafePointer<FSEventStreamEventId>) {
////
//            let eventStream = unsafeBitCast(clientCallbackInfo, to: EventStream.self)
//            let nsEventPaths = unsafeBitCast(eventPaths, to: NSArray.self)
////
////            var events = [FileEvent]()
//            eventPaths.
//            
//            for i in 0..<Int(numEvents) {
//                let event = FileEvent(path: paths[i] as! String, flags: FileEventFlags(rawValue: eventFlags[i]))
//                events.append(event)
//            }
////
//            eventStream.changeHandler(events)
//        }
//                
//        guard let stream = FSEventStreamCreate(nil, callback, nil, [path] as NSArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 5, flags) else { return nil }
//        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
//        FSEventStreamStart(stream)
//        return Watcher(stream: stream)
//    }
//    
//}
