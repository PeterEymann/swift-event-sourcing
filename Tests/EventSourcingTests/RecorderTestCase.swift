//
//  RecorderTestCase.swift
//  
//
//  Created by Peter Eymann on 01/02/22.
//

import XCTest
@testable import EventSourcing


func testRecorder(recorder: AggregateRecorder) throws {
    /// Use this to test yout implementations of RecordsDomainEvents
    let originatorId = UUID()
    let storedEvent1 = StoredEvent(originatorId: originatorId, originatorVersion: 1, topic: "topic1", state: "state1".data(using: .utf8)!)
    let storedEvent2 = StoredEvent(originatorId: originatorId, originatorVersion: 2, topic: "topic2", state: "state2".data(using: .utf8)!)
    
    try recorder.insertEvents([storedEvent1, storedEvent2])
    var results = try recorder.selectEvents(originatorId: originatorId)
    XCTAssertEqual(results.count, 2)
    XCTAssertEqual(results[0].originatorId, originatorId)
    XCTAssertEqual(results[0].originatorVersion, 1)
    XCTAssertEqual(results[0].topic, "topic1")
    XCTAssertEqual(String(decoding: results[0].state, as: UTF8.self), "state1")
    XCTAssertEqual(results[1].originatorId, originatorId)
    XCTAssertEqual(results[1].originatorVersion, 2)
    XCTAssertEqual(results[1].topic, "topic2")
    XCTAssertEqual(String(decoding: results[1].state, as: UTF8.self), "state2")
    
    /// check recorded events are unique
    let storedEvent3 = StoredEvent(originatorId: originatorId, originatorVersion: 3, topic: "topic3", state: "state3".data(using: .utf8)!)
    
    /// check event can't be overwritten
    XCTAssertThrowsError(try recorder.insertEvents([storedEvent2, storedEvent3])) {
        error in XCTAssertEqual(error as? RecorderError, RecorderError.IntegrityError)
    }
    
    /// check writing of tests is atomic
    results = try recorder.selectEvents(originatorId: originatorId)
    XCTAssertEqual(results.count, 2)
    
    /// check the third event can be written
    try recorder.insertEvents([storedEvent3])
    results = try recorder.selectEvents(originatorId: originatorId)
    XCTAssertEqual(results.count, 3)
    XCTAssertEqual(results[2].originatorId, originatorId)
    XCTAssertEqual(results[2].originatorVersion, 3)
    XCTAssertEqual(results[2].topic, "topic3")
    XCTAssertEqual(String(decoding: results[2].state, as: UTF8.self), "state3")
    
    /// check we can get events after the first
    results = try recorder.selectEvents(originatorId: originatorId, gt: 1)
    XCTAssertEqual(results.count, 2)
    XCTAssertEqual(results[0].originatorId, originatorId)
    XCTAssertEqual(results[0].originatorVersion, 2)
    XCTAssertEqual(results[1].originatorId, originatorId)
    XCTAssertEqual(results[1].originatorVersion, 3)
    
    /// check we can get the last event
    results = try recorder.selectEvents(originatorId: originatorId, desc: true, limit: 1)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].originatorId, originatorId)
    XCTAssertEqual(results[0].originatorVersion, 3)


}


class RecorderTestCase: XCTestCase {

    func testInMemoryRecorder() throws {
        let recorder = InMemoryAggregateRecorder()
        try testRecorder(recorder: recorder)
    }
}
