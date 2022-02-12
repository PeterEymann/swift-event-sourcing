//
//  Application.swift
//  
//
//  Created by Peter Eymann on 04/02/22.
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

public protocol ApplicationProtocol {
    /// Application services allow interfaces to use a domain model without dealing directly with the aggregates.
    /// The domain model can be presented in a variety of interfaces without replicating the functionality of the
    /// application services in multiple interfaces.
    func save(_ aggregates: CollectsDomainEvents...) throws
    func takeSnapshot<T: Aggregate & GenericAggregate>(aggregateType: T.Type, aggregateId: UUID, version: Int) throws
}


public protocol NotifiesEvents {
    func notify(newEvents: [DomainEvent])
}

public protocol HasName {
    static var name: String { get }
}

open class Application: ApplicationProtocol {
    /// Subclass your applications from here
    let factory: CreatesInfrastructure
    let mapper: MapsDomainEvents
    let recorder: ApplicationRecorder
    let events: StoresEvents
    let snapshots: StoresEvents?
    public let repository: GetsDomainEventsFromStore
    public let log: NotificationLog
    
    public required init () {
        @Injected(\.infrastructureFactory) var factory: CreatesInfrastructure
        mapper = factory.buildMapper()
        recorder = Self.buildRecorder(infrastructureFactory: factory)
        events = Self.buildEventstore(recorder: recorder, mapper: mapper)
        snapshots = Self.buildSnapshotStore(factory: factory, mapper: mapper)
        repository = Self.buildRepository(eventStore: events, snapshotStore: snapshots)
        log = Self.buildNotificationLog(recorder: recorder)
        self.factory = factory
    }
        
    class func buildRecorder(infrastructureFactory: CreatesInfrastructure) -> ApplicationRecorder {
        return infrastructureFactory.buildApplicationRecorder()
    }

    
    class func buildEventstore(recorder: ApplicationRecorder, mapper: MapsDomainEvents) -> EventStore {
        return EventStore(recorder: recorder, mapper: mapper)
    }

    class func buildSnapshotStore(factory: CreatesInfrastructure, mapper: MapsDomainEvents) -> EventStore? {
        if factory.isSnapshottingEnabled {
            return EventStore(recorder: factory.buildAggregateRecorder(), mapper: mapper)
        } else {
            return nil
        }
    }

    class func buildRepository(eventStore: StoresEvents, snapshotStore: StoresEvents?) -> GetsDomainEventsFromStore {
        return Repository(eventSore: eventStore, snapshotStore: snapshotStore)
    }
    
    class func buildNotificationLog(recorder: ApplicationRecorder) -> NotificationLog {
        return LocalNotificationLog(recorder: recorder, sectionSize: 10)
    }
    
    public func save(_ aggregates: CollectsDomainEvents...) throws {
        var events: [DomainEvent] = []
        for aggregate in aggregates {
            for e in aggregate.collect() {
                events.append(e)
            }
        }
        try self.events.put(events)
        if let notifying = self as? NotifiesEvents {
            notifying.notify(newEvents: events)
        }
    }
    
    public func takeSnapshot<T: Aggregate & GenericAggregate>(aggregateType: T.Type, aggregateId: UUID, version: Int) throws {
        let aggregate: T = try repository.get(aggregateId: aggregateId, version: version)
        let snapShot = Snapshot.take(aggregate: aggregate)
        try snapshots!.put([snapShot])
    }
}
