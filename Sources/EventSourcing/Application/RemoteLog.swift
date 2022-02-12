//
//  RemoteLog.swift
//  
//
//  Created by Peter Eymann on 05/02/22.
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

public protocol NotificationLogView {
    /// Presents serialised notification log sections.
    func get(sectionId: String) -> Data
}

public protocol NotificationLogAPI {
    /// Represents an application log in serialized format
    func getLogSection(sectionId: String) -> Data
}

public protocol ApplicationAdapter {
    /// 
    associatedtype TApplication: Application
    
    var app: TApplication { get }
    var log: NotificationLogView { get }
}

struct SerializableLogItem: Codable {
    let id: Int
    let originatorId: UUID
    let originatorVersion: Int
    let topic: String
    let state: String
    
    init (_ from: Notification) {
        id = from.id
        originatorId = from.originatorId
        originatorVersion = from.originatorVersion
        topic = from.topic
        state = from.state.base64EncodedString()
    }
}

struct SerializableLogSection: Codable {
    let sectionid: String?
    let nextId: String?
    let items: [SerializableLogItem]
}

public class JSONNotificationLogView: NotificationLogView {
    /// Presents notification log sections in JSON format.
    let log: LocalNotificationLog
    
    public init (log: LocalNotificationLog) {
        self.log = log
    }
    
    public func get(sectionId: String) -> Data {
        let section = log[sectionId]
        let encoder = JSONEncoder()
        var logItems: [SerializableLogItem] = []
        for item in section.items {
            logItems.append(SerializableLogItem.init(item))
        }
        return try! encoder.encode(SerializableLogSection(sectionid: section.sectionId, nextId: section.nextId, items: logItems))
    }
}

public final class RemoteNotificationLog: NotificationLog {
    let api: NotificationLogAPI
    
    public init (api: NotificationLogAPI) {
        self.api = api
    }
    
    public subscript(sectionId: String) -> Section {
        let body = api.getLogSection(sectionId: sectionId)
        let serializableLogSection = try! JSONDecoder().decode(SerializableLogSection.self, from: body)
        var notifications: [Notification] = []
        for item in serializableLogSection.items {
            notifications.append(Notification(
                id: item.id, originatorId: item.originatorId, originatorVersion: item.originatorVersion, topic: item.topic, state: Data(base64Encoded: item.state)!
            ))
        }
        return Section(sectionId: serializableLogSection.sectionid, items: notifications, nextId: serializableLogSection.nextId)
    }
}
