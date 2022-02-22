//
//  DomainEvent.swift
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

public typealias JSONDict = [String:Any]

public struct DomainEventData: Codable {
    /// Contains the minimum state of a domain event
    let originatorId: UUID
    let originatorVersion: Int
    let timeStamp: Date
    
    public init(_ jsonDict: JSONDict) {
        originatorId = jsonDict["originatorId"] as! UUID
        originatorVersion = jsonDict["originatorVersion"] as! Int
        timeStamp = jsonDict["timeStamp"] as! Date
    }
}

public protocol TextRepresentable {
    var description: String { get }
}

public protocol DomainEvent: Codable, TextRepresentable {
    /// An immutable domain event
    var data: DomainEventData { get }

    init(_ jsonDict: JSONDict)
    func mutate<T: Aggregate>(obj: inout T?) throws
}

public extension DomainEvent {
    /// The basic structure of a domain event.
    static func fromJSON(_ decoder: JSONDecoder, _ state: Data) throws -> Self {
        /// reconstruct an event from JSON
        let event = try decoder.decode(self, from: state)
        return event
    }
    
    func toStoredEvent(mapper: MapsDomainEvents) throws -> StoredEvent {
        /// convert a domain event into a stored event
        return try mapper.fromDomainEvent(self)
    }
    
    var originatorId: UUID {
        return self.data.originatorId
    }
    
    var originatorVersion: Int {
        return self.data.originatorVersion
    }
    
    var timeStamp: Date {
        return self.data.timeStamp
    }
    
    var description: String {
        return "DomainEvent #\(self.originatorVersion) for \(self.originatorId) fired at \(self.timeStamp)"
    }
    
    func mutate<T: Aggregate>(obj: inout T?) throws {
    }
}

public protocol StoreableEvent: DomainEvent {}
