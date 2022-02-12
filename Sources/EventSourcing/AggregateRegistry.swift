//
//  AggregateRegistry.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
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

private struct AggregateRegistryKey: InjectionKey {
    static var currentValue: RegistersAggregates = AggregateRegistry()
}

extension InjectedValues {
    public var aggregateRegistry: RegistersAggregates {
        get { Self[AggregateRegistryKey.self] }
        set { Self[AggregateRegistryKey.self] = newValue }
    }
}

public protocol RegistersAggregates {
    mutating func addAggregate(topic: String, aggregateClass: GenericAggregate.Type)
    func resolveAggregate(_ topic: String) throws -> GenericAggregate.Type
    func resolveDomainEvent(_ topic: String) throws -> DomainEvent.Type
    func getTopic(for domainEventType: DomainEvent.Type) throws -> String?
    func getTopic(for aggregateType: GenericAggregate.Type) throws -> String?
}

public struct AggregateRegistry: RegistersAggregates {
    /// Global registry for Aggregates and Domain Events
    var aggregates: [String:GenericAggregate.Type] = [:]
    var domainEvents: [String:DomainEvent.Type] = ["snapshot":Snapshot.self]
    public init () {}
    
    mutating public func addAggregate(topic: String, aggregateClass: GenericAggregate.Type) {
        aggregates.updateValue(aggregateClass, forKey: topic)
        // add event topic
        for event in aggregateClass.events {
            domainEvents["\(topic).\(String(describing: event))"] = event
        }
    }
    
    public func resolveAggregate(_ topic: String) throws -> GenericAggregate.Type {
        if let aggregateType = aggregates[topic] {
            return aggregateType
        } else {
            throw AggregateError.ObjectNotFound(topic)
        }
    }

    public func resolveDomainEvent(_ topic: String) throws -> DomainEvent.Type {
        if let eventType = domainEvents[topic] {
            return eventType
        } else {
            throw AggregateError.ObjectNotFound(topic)
        }
    }
    
    public func getTopic(for domainEventType: DomainEvent.Type) throws -> String? {
        for (topic, cls) in domainEvents {
            if cls == domainEventType {
                return topic
            }
        }
        throw AggregateError.TopicNotFound
    }

    public func getTopic(for aggregateType: GenericAggregate.Type) throws -> String? {
        for (topic, cls) in aggregates {
            if cls == aggregateType {
                return topic
            }
        }
        throw AggregateError.TopicNotFound
    }
}
