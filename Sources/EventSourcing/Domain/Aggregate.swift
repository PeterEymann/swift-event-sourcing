//
//  Aggregate.swift
//  
//
//  Created by Peter Eymann on 24/01/22.
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


public enum AggregateError: Error, Equatable {
    case VersionError(expected: Int, given: Int)
    case ObjectNotFound(_ topic: String)
    case TopicNotFound
}


public protocol AggregateEvent: StoreableEvent {
    /// A domain event that is part of an aggregate
    func apply<T: Aggregate>(obj: inout T) throws
}

extension AggregateEvent {
    func mutate<T: Aggregate>(obj: inout T?) throws {
        /// Changes the state of the aggregate according to domain event attributes.
        // check event is next in sequence
        // use counting to follow the sequence
        var aggregate = obj!
        let nextVersion = aggregate.state.version + 1
        if self.originatorVersion != nextVersion {
            throw AggregateError.VersionError(
                expected: self.originatorVersion, given: nextVersion
            )
        }
        // update the aggregate version
        aggregate.state.version = nextVersion
        // update the modified time
        aggregate.state.modifiedOn = self.timeStamp
        try self.apply(obj: &aggregate)
    }
    
    func apply<T: Aggregate>(obj: inout T) {}
}

public protocol AggregateCreatedEvent: AggregateEvent {
    /// A special type of aggregate event that creates a new instance of an aggregate.
    associatedtype AggregateType: Aggregate
    var originatorTopic: String { get }
    
    func createAggregate() -> AggregateType
}


extension AggregateCreatedEvent {
    func mutate<T: Aggregate>(obj: inout T?) throws {
        /// Constructs aggregate instance defined by domain event object attributes
        let found = try InjectedValues[\.aggregateRegistry].resolveAggregate(originatorTopic)
        if found is AggregateType.Type {
            obj = self.createAggregate() as? T
        }
    }
}


public protocol AggregateState: Codable {
    /// The codable state of an aggregate
    var id: UUID { get }
    var version: Int { get set }
    var createdOn: Date { get }
    var modifiedOn: Date { get set }
}

public protocol CollectsDomainEvents {
    /// Defines the collect function of an Aggregate
    func collect() -> [DomainEvent]
}

public protocol Aggregate: AnyObject, CollectsDomainEvents {
    /// Main interface for Aggregates
    associatedtype State: AggregateState
    
    var state: State { get set }
    var pendingEvents: [DomainEvent] { get set }
    
    init (state: State)
    static func fromData(_ data: Data) -> Self
    static func makeAggregate<T: AggregateCreatedEvent>(eventType: T.Type, payload: JSONDict) throws -> T.AggregateType
    func triggerEvent<T: AggregateEvent, A: Aggregate>(_ eventType: T.Type, for instance: A, payload: JSONDict?) throws
}

extension Aggregate {
    public var id: UUID { self.state.id }
    var version: Int { self.state.version }
    var createdOn: Date { self.state.createdOn }
    var modifiedOn: Date { self.state.modifiedOn }
        
    public static func fromData(_ data: Data) -> Self {
        /// Reconstruct the state of an Aggregate from serializable data
        self.init(state: try! JSONDecoder().decode(State.self, from: data))
    }

    public func collect() -> [DomainEvent] {
        /// Pop all pending events
        var collected: [DomainEvent] = []
        while !self.pendingEvents.isEmpty {
            collected.append(self.pendingEvents[0])
            self.pendingEvents.remove(at: 0)
        }
        return collected
    }

    public func triggerEvent<T: AggregateEvent, A: Aggregate>(_ eventType: T.Type, for instance: A, payload: JSONDict?=nil) throws {
        /// Trigger a new Aggregate Event
        var args: JSONDict
        if let data = payload {
            args = data
        } else {
            args = [:]
        }
        
        args["originatorId"] = instance.id
        args["originatorVersion"] = instance.version + 1
        args["timeStamp"] = Date()
        let event = eventType.init(args)
        var this: A? = instance
        try event.mutate(obj: &this)
        instance.pendingEvents.append(event)
    }
}


public protocol HasEvents: AnyObject {
    /// Applicable to all aggregates that have aggregate events
    static var events: [DomainEvent.Type] { get }
}


open class GenericAggregate: HasEvents {
    /// Subclass this to define new Aggregates
    public class var events: [DomainEvent.Type] {
        /// Here we define the domain events that belong to this Aggregate
        fatalError("Aggregate.events not implemented")
    }

    public class func makeAggregate<T: AggregateCreatedEvent>(eventType: T.Type, payload: JSONDict) throws -> T.AggregateType {
        /// Create a new instance from an `AggregateCreatedEvent`
        var args = payload
        args["originatorId"] = UUID()
        args["originatorVersion"] = 1
        args["timeStamp"] = Date()
        args["originatorTopic"] = try InjectedValues[\.aggregateRegistry].getTopic(for: self)!
        let event = eventType.init(args)
        var aggregate: T.AggregateType? = nil
        try event.mutate(obj: &aggregate)
        // append the domain event to pending list
        aggregate!.pendingEvents.append(event)
        return aggregate!
    }
}
