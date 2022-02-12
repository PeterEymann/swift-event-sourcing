//
//  AggregateRecorder.swift
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


public enum RecorderError: Error {
    case OperationalError
    case IntegrityError
}


public protocol AggregateRecorder {
    /// Writes stored events into database.
    func insertEvents(_ events: [StoredEvent], tracking: Tracking?) throws
    /// Reads stored events from database.
    func selectEvents(originatorId: UUID, gt: Int?, lte: Int?, desc: Bool, limit: Int?) throws -> [StoredEvent]
}


public extension AggregateRecorder {
    func selectEvents(originatorId: UUID, gt: Int?=nil, lte: Int?=nil, desc: Bool=false, limit: Int?=nil) throws -> [StoredEvent] {
        return try selectEvents(originatorId: originatorId, gt: gt, lte: lte, desc: desc, limit: limit)
    }
    
    func insertEvents(_ events: [StoredEvent], tracking: Tracking?=nil) throws {
        try insertEvents(events, tracking: tracking)
    }
}

