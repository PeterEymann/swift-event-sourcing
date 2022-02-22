//
//  TrackingTestCase.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
//

import XCTest
@testable import EventSourcing

func testProcessRecorder(recorder: ProcessRecorder) throws {
    // get current position
    XCTAssertEqual(recorder.maxTrackingId(applicationName: "upstreamApp"), 0)
    
    // write two stored events
    let originatorId1 = UUID()
    let originatorId2 = UUID()
    let storedEvent1 = StoredEvent(originatorId: originatorId1, originatorVersion: 0, topic: "topic1", state: "state1".data(using: .utf8)!)
    let storedEvent2 = StoredEvent(originatorId: originatorId1, originatorVersion: 1, topic: "topic2", state: "state2".data(using: .utf8)!)
    let storedEvent3 = StoredEvent(originatorId: originatorId2, originatorVersion: 1, topic: "topic3", state: "state3".data(using: .utf8)!)
    
    let tracking1 = Tracking(applicationName: "upstreamApp", notificationId: 1)
    let tracking2 = Tracking(applicationName: "upstreamApp", notificationId: 2)
    
    try recorder.insertEvents([storedEvent1, storedEvent2], tracking: tracking1)
    
    // get current position
    XCTAssertEqual(recorder.maxTrackingId(applicationName: "upstreamApp"), 1)

    // check event can't be overwritten
    XCTAssertThrowsError(try recorder.insertEvents([storedEvent3], tracking: tracking1)) {
        error in XCTAssertEqual(error as? RecorderError, RecorderError.IntegrityError)
    }
    
    // get current position
    XCTAssertEqual(recorder.maxTrackingId(applicationName: "upstreamApp"), 1)

    try recorder.insertEvents([storedEvent3], tracking: tracking2)
    // get current position
    XCTAssertEqual(recorder.maxTrackingId(applicationName: "upstreamApp"), 2)
}


class TrackingTestCase: XCTestCase {
    func testInMemoryProcessRecorder() throws {
        let recorder = InMemoryProcessRecorder()
        try testProcessRecorder(recorder: recorder)
    }
}
