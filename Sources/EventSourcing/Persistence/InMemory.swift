//
//  InMemory.swift
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

public class InMemoryAggregateRecorder: AggregateRecorder {
    /// Stores aggregates events in memory
    var storedEvents: [StoredEvent] = []
    var storedEventIndex: [UUID:[Int:Int]] = [:]
    let lock = NSLock()
    
    public init() {}
    
    public func insertEvents(_ events: [StoredEvent], tracking: Tracking?) throws {
        lock.lock()
        defer {
            lock.unlock()
        }
        try self.assertUniqueness(events)
        self.updateTable(events)
    }
    
    func assertUniqueness(_ events: [StoredEvent]) throws {
        for event in events {
            if storedEventIndex[event.originatorId] != nil {
                if storedEventIndex[event.originatorId]!.keys.contains(event.originatorVersion) {
                    throw RecorderError.IntegrityError
                }
            }
        }
    }
    
    func updateTable(_ events: [StoredEvent]) {
        for event in events {
            self.storedEvents.append(event)
            let index = self.storedEvents.count - 1
            if storedEventIndex[event.originatorId] == nil {
                storedEventIndex[event.originatorId] = [event.originatorVersion:index]
            } else {
                self.storedEventIndex[event.originatorId]?.updateValue(index, forKey: event.originatorVersion)
            }
        }
    }
    
    public func selectEvents(originatorId: UUID, gt: Int?=nil, lte: Int?=nil, desc: Bool=false, limit: Int?=nil) -> [StoredEvent] {
        lock.lock()
        defer {
            lock.unlock()
        }
        var results: [StoredEvent] = []
        if let index = storedEventIndex[originatorId] {
            var positions = [Int](index.keys.sorted())
            if desc {
                positions = positions.reversed()
            }
            for p in positions {
                if gt != nil {
                    if p <= gt! {
                        continue
                    }
                }
                if lte != nil {
                    if p > lte! {
                        continue
                    }
                }
                let event = self.storedEvents[index[p]!]
                results.append(event)
                if results.count == limit {
                    break
                }
            }
        }
        return results
    }
}


public class InMemoryApplicationRecorder: InMemoryAggregateRecorder, ApplicationRecorder {
    public func selectNotifications(start: Int, limit: Int) -> [Notification] {
        lock.lock()
        defer {
            lock.unlock()
        }
        var results: [Notification] = []
        if (storedEvents.count <= start - 1) {
            return results
        }
        let i = start - 1
        let j: Int
        if i + limit > storedEvents.count {
            j = storedEvents.count - 1
        } else {
            j = i + limit - 1
        }
        var cnt = start
        for storedEvent in storedEvents[i...j] {
            results.append(Notification(id: cnt, storedEvent: storedEvent))
            cnt += 1
        }
        return results
    }
    
    public func maxNotificationId() -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }
        return storedEvents.count
    }
}

public class InMemoryProcessRecorder: InMemoryApplicationRecorder, ProcessRecorder {
    private var trackingTable: [String:Int] = [:]
    
    func assertUniqueness(_ events: [StoredEvent], tracking: Tracking) throws {
        try self.assertUniqueness(events)
        let last: Int
        if let value = trackingTable[tracking.applicationName] {
            last = value
        } else {
            last = 0
        }
        if tracking.notificationId <= last {
            throw RecorderError.IntegrityError
        }
    }
    
    public func maxTrackingId(applicationName: String) -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let last = trackingTable[applicationName] {
            return last
        } else {
            return 0
        }
    }

    override public func insertEvents(_ events: [StoredEvent], tracking: Tracking?) throws {
        lock.lock()
        defer {
            lock.unlock()
        }
        try self.assertUniqueness(events, tracking: tracking!)
        self.updateTable(events, tracking: tracking!)
    }
    
    public func updateTable(_ events: [StoredEvent], tracking: Tracking) {
        self.updateTable(events)
        trackingTable[tracking.applicationName] = tracking.notificationId
    }
}

