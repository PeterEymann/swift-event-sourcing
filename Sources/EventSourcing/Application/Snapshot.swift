//
//  Snapshot.swift
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

public struct Snapshot: StoreableEvent {
    /// A snapshot records the current state of an aggregate. Snapshots can be used to speed up
    /// the access time of event-sourced aggregates.
    public let data: DomainEventData
    let topic: String
    let state: Data
    
    public init(_ jsonDict: JSONDict) {
        data = DomainEventData(jsonDict)
        self.topic = jsonDict["topic"] as! String
        self.state = jsonDict["state"] as! Data
    }
    
    public static func take<T: Aggregate & GenericAggregate>(aggregate: T) -> Self {
        return Self([
            "originatorId": aggregate.id,
            "originatorVersion": aggregate.version,
            "timeStamp": Date(),
            "topic": try! InjectedValues[\.aggregateRegistry].getTopic(for: T.self)!,
            "state": try! JSONEncoder().encode(aggregate.state)
        ])
    }
    
    public func mutate<T: Aggregate>(obj: inout T?) throws {
        assert(obj == nil)
        let aggregateType = try InjectedValues[\.aggregateRegistry].resolveAggregate(topic)
        if let t = aggregateType as? T.Type {
            obj = t.fromData(state)
        }
    }
}
