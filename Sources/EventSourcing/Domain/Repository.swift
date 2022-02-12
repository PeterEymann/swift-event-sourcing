//
//  Repository.swift
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

public enum RepositoryErrors: Error {
    case AggregateNotFound
}

public protocol GetsDomainEventsFromStore {
    /// A repository provides an interface for accessing aggregates by their ID.
    func get<T: Aggregate>(aggregateId: UUID, version: Int?) throws -> T
}

extension GetsDomainEventsFromStore {
    public func get<T: Aggregate>(aggregateId: UUID, version: Int?=nil) throws -> T {
        return try get(aggregateId: aggregateId, version: version)
    }
}

public final class Repository: GetsDomainEventsFromStore {
    let eventStore: StoresEvents
    let snapshotStore: StoresEvents?


    public init (eventSore: StoresEvents, snapshotStore: StoresEvents?=nil) {
        self.eventStore = eventSore
        self.snapshotStore = snapshotStore
    }
    
    public func get<T: Aggregate>(aggregateId: UUID, version: Int?=nil) throws -> T {
        var gt: Int? = nil
        var domainEvents: [StoreableEvent] = []
        
        // try to get a snapshot
        if let store = snapshotStore {
            let snapshots = try! store.get(originatorId: aggregateId, lte: version, desc: true, limit: 1)
            if !snapshots.isEmpty {
                let snapshot = snapshots[0]
                gt = snapshot.originatorVersion
                domainEvents.append(snapshot as! StoreableEvent)
            }
        }
        
        // get the domain events
        for event in try! eventStore.get(originatorId: aggregateId, gt: gt, lte: version) {
            domainEvents.append(event as! StoreableEvent)
        }
        
        // project the domain events
        var aggregate: T? = nil
        for event in domainEvents {
            try event.mutate(obj: &aggregate)
        }
        if aggregate == nil {
            throw RepositoryErrors.AggregateNotFound
        }
        return aggregate!
    }
}
