//
//  NotificationLog.swift
//  
//
//  Created by Peter Eymann on 02/02/22.
//
//  Copyright 2022 Peter Eymann
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation

public func formatSectionId(first: Int, limit: Int) -> String {
    return "\(first),\(limit)"
}

public struct Section: Codable {
    /// A section of a Notification Log
    internal init(sectionId: String?, items: [Notification], nextId: String?) {
        self.sectionId = sectionId
        self.items = items
        self.nextId = nextId
    }
    
    public let sectionId: String?
    public let items: [Notification]
    public let nextId: String?
}


public protocol NotificationLog {
    /// Returns section of a notification protocol
    subscript(sectionId: String) -> Section { get }
}


public final class LocalNotificationLog: NotificationLog {
    let recorder: ApplicationRecorder
    let DefaultSectionSize = 10
    let sectionSize: Int
    
    public init (recorder: ApplicationRecorder, sectionSize: Int?=nil) {
        self.recorder = recorder
        if sectionSize == nil {
            self.sectionSize = DefaultSectionSize
        } else {
            self.sectionSize = sectionSize!
        }
    }
        
    public subscript(sectionId: String) -> Section {
        return self.getItem(sectionId: sectionId)
    }
    
    func getItem(sectionId: String) -> Section {
        // interpret the section id
        let parts = sectionId.components(separatedBy: ",")
        let part1 = Int(parts[0])!
        let part2 = Int(parts[1])!
        let start = max(1, part1)
        let limit = min(max(0, part2 - start + 1), sectionSize)
        // select notifications
        let notifications = recorder.selectNotifications(start: start, limit: limit)
        let returnId: String?
        let nextId: String?
        if !notifications.isEmpty {
            let lastId = notifications.last!.id
            returnId = formatSectionId(first: notifications[0].id, limit: lastId)
            if notifications.count == limit {
                let nextStart = lastId + 1
                nextId = formatSectionId(first: nextStart, limit: nextStart + limit - 1)
            } else {
                nextId = nil
            }
        } else {
            returnId = nil
            nextId = nil
        }
        return Section(sectionId: returnId, items: notifications, nextId: nextId)
    }
}
