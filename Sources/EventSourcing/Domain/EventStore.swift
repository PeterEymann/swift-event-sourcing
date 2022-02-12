//
//  EventStore.swift
//  
//
//  Created by Peter Eymann on 01/02/22.
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

public protocol StoresEvents {
    func put(_ events: [DomainEvent], tracking: Tracking?) throws
    func get(originatorId: UUID, gt: Int?, lte: Int?, desc: Bool, limit: Int?) throws -> [DomainEvent]
}

extension StoresEvents {
    public func get(originatorId: UUID, gt: Int?=nil, lte: Int?=nil, desc: Bool=false, limit: Int?=nil) throws -> [DomainEvent] {
        try self.get(originatorId: originatorId, gt: gt, lte: lte, desc: desc, limit: limit)
    }
    
    public func put(_ events: [DomainEvent], tracking: Tracking?=nil) throws {
        try put(events, tracking: tracking)
    }
}


public final class EventStore: StoresEvents {
    let mapper: MapsDomainEvents
    let recorder: AggregateRecorder
    
    public init (recorder: AggregateRecorder, mapper: MapsDomainEvents) {
        self.recorder = recorder
        self.mapper = mapper
    }
    
    public func put(_ events: [DomainEvent], tracking: Tracking?) throws {
        /// stores domain events in aggregate sequence.
        var storedEvents: [StoredEvent] = []
        for domainEvent in events {
            storedEvents.append(try domainEvent.toStoredEvent(mapper: mapper))
        }
        try recorder.insertEvents(storedEvents, tracking: tracking)
    }

    public func get(originatorId: UUID, gt: Int?=nil, lte: Int?=nil, desc: Bool=false, limit: Int?=nil) throws -> [DomainEvent] {
        let storedEvents = try recorder.selectEvents(originatorId: originatorId, gt: gt, lte: lte, desc: desc, limit: limit)
        var result: [DomainEvent] = []
        for storedEvent in storedEvents {
            result.append(try mapper.toDomainEvent(storedEvent))
        }
        return result
    }

}
