//
//  Notification.swift
//  
//
//  Created by Peter Eymann on 10/02/22.
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

public struct Notification: Identifiable, Codable {
    /// To propagate the state of an application, we need to follow a single sequence, but the application’s
    /// domain model events are each only in their own aggregate sequence.
    /// Therefore, to propagate the state of a domain model in a reliable way, all the domain events must be
    /// ordered serially. By positioning each domain event in both an aggregate sequence and an event notification
    /// sequence, the state of a domain model as a whole can be propagated reliably.
    
    public init(id: Int, storedEvent: StoredEvent) {
        self.id = id
        self.storedEvent = storedEvent
    }
    
    public init(id: Int, originatorId: UUID, originatorVersion: Int, topic: String, state: Data) {
        self.init(id: id, storedEvent: StoredEvent(originatorId: originatorId, originatorVersion: originatorVersion, topic: topic, state: state))
    }
    
    public let id: Int
    public let storedEvent: StoredEvent
    
    public var originatorId: UUID {
        storedEvent.originatorId
    }
    
    public var originatorVersion: Int {
        storedEvent.originatorVersion
    }
    
    public var topic: String {
        storedEvent.topic
    }
    
    public var state: Data {
        storedEvent.state
    }
}
