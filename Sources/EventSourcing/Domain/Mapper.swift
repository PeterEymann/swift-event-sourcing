//
//  Mapper.swift
//  
//
//  Created by Peter Eymann on 31/01/22.
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

public struct StoredEvent: Codable {
    /// A stored Domain Event
    public let originatorId: UUID
    public let originatorVersion: Int
    public let topic: String
    public let state: Data
    
    public init(originatorId: UUID, originatorVersion: Int, topic: String, state: Data) {
        self.originatorId = originatorId
        self.originatorVersion = originatorVersion
        self.topic = topic
        self.state = state
    }
}


public protocol MapsDomainEvents {
    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }
    func fromDomainEvent<T: DomainEvent>(_ event: T) throws -> StoredEvent
    func toDomainEvent(_ storedEvent: StoredEvent) throws -> DomainEvent
}


class Mapper: MapsDomainEvents {
    @Injected(\.aggregateRegistry) var registry: RegistersAggregates
    public let encoder = JSONEncoder()
    public let decoder = JSONDecoder()
    
    func fromDomainEvent<T: DomainEvent>(_ event: T) throws -> StoredEvent {
        let topic = try self.registry.getTopic(for: T.self)!
        return StoredEvent(
            originatorId: event.originatorId,
            originatorVersion: event.originatorVersion,
            topic: topic,
            state: try self.encoder.encode(event)
        )
    }
    
    func toDomainEvent(_ storedEvent: StoredEvent) throws -> DomainEvent
    {
        let eventType = try self.registry.resolveDomainEvent(storedEvent.topic)
        return try eventType.fromJSON(self.decoder, storedEvent.state)
    }
}
