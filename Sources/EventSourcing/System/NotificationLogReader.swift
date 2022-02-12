//
//  File.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
//

import Foundation


public struct NotificationLogReader {
    /// Reads notifications from a local or remote notification log
    /// Starts from a given position in the notification sequence
    
    internal let notificationLog: NotificationLog
    internal let sectionSize: Int
    
    init (_ notificationLog: NotificationLog, sectionSize: Int?=10) {
        self.notificationLog = notificationLog
        self.sectionSize = sectionSize!
    }
    
    public func read(start: Int) -> [Notification] {
        var notifications: [Notification] = []
        var sectionId = "\(start),\(start + sectionSize - 1)"
        while true {
            let section = notificationLog[sectionId]
            for item in section.items {
                if item.id < start {
                    continue
                }
                notifications.append(item)
            }
            if section.nextId == nil {
                break
            } else {
                sectionId = section.nextId!
            }
        }
        return notifications
    }
}
