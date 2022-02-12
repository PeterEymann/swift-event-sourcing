//
//  ApplicationRecorderTestCase.swift
//  
//
//  Created by Peter Eymann on 02/02/22.
//

import XCTest
@testable import EventSourcing

func testApplicationRecorder(recorder: ApplicationRecorder & AggregateRecorder) throws {
    let originatorId1 = UUID()
    let originatorId2 = UUID()
    let storedEvent1 = StoredEvent(originatorId: originatorId1, originatorVersion: 0, topic: "topic1", state: "state1".data(using: .utf8)!)
    let storedEvent2 = StoredEvent(originatorId: originatorId1, originatorVersion: 1, topic: "topic2", state: "state2".data(using: .utf8)!)
    let storedEvent3 = StoredEvent(originatorId: originatorId2, originatorVersion: 1, topic: "topic3", state: "state3".data(using: .utf8)!)

    try recorder.insertEvents([storedEvent1, storedEvent2])
    try recorder.insertEvents([storedEvent3])
    
    let storedEvents1 = try recorder.selectEvents(originatorId: originatorId1)
    let storedEvents2 = try recorder.selectEvents(originatorId: originatorId2)

    /// check we got what was written
    XCTAssertEqual(storedEvents1.count, 2)
    XCTAssertEqual(storedEvents2.count, 1)
    
    XCTAssertEqual(recorder.maxNotificationId(), 3)
    var notifications = recorder.selectNotifications(start: 1, limit: 10)
    XCTAssertEqual(notifications.count, 3)
    XCTAssertEqual(notifications[0].id, 1)
    XCTAssertEqual(notifications[0].topic, "topic1")
    XCTAssertEqual(String(decoding: notifications[0].state, as: UTF8.self), "state1")
    XCTAssertEqual(notifications[1].id, 2)
    XCTAssertEqual(notifications[1].topic, "topic2")
    XCTAssertEqual(String(decoding: notifications[1].state, as: UTF8.self), "state2")
    XCTAssertEqual(notifications[2].id, 3)
    XCTAssertEqual(notifications[2].topic, "topic3")
    XCTAssertEqual(String(decoding: notifications[2].state, as: UTF8.self), "state3")
    
    notifications = recorder.selectNotifications(start: 3, limit: 10)
    XCTAssertEqual(notifications.count, 1)
    XCTAssertEqual(notifications[0].id, 3)
    XCTAssertEqual(notifications[0].topic, "topic3")
    XCTAssertEqual(String(decoding: notifications[0].state, as: UTF8.self), "state3")
}
    

class ApplicationRecorderTestCase: XCTestCase {
    func testInMemoryApplicationRecorder() throws {
        let recorder = InMemoryApplicationRecorder()
        try testApplicationRecorder(recorder: recorder)
    }
}
