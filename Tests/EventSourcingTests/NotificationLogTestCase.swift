//
//  NotificationLogTestCase.swift
//  
//
//  Created by Peter Eymann on 02/02/22.
//

import XCTest
@testable import EventSourcing

class NotificationLogTestCase: XCTestCase {
    func testLocalNotificationLog() throws {
        let recorder = InMemoryApplicationRecorder()
        let notificationLog = LocalNotificationLog(recorder: recorder, sectionSize: 5)
        
        // get first section of log
        var section = notificationLog["1,5"]
        XCTAssertTrue(section.items.isEmpty)
        XCTAssertNil(section.sectionId)
        XCTAssertNil(section.nextId)
        
        // write 5 events
        var originatorId = UUID()
        for index in 1...5 {
            let storedEvent = StoredEvent(originatorId: originatorId, originatorVersion: index, topic: "topic", state: "state".data(using: .utf8)!)
            try recorder.insertEvents([storedEvent])
        }
        
        // get the first section of the log
        section = notificationLog["1,5"]
        XCTAssertEqual(section.items.count, 5)
        XCTAssertEqual(section.sectionId, "1,5")
        XCTAssertEqual(section.nextId, "6,10")
        
        // write 4 events
        originatorId = UUID()
        for index in 1...4 {
            let storedEvent = StoredEvent(originatorId: originatorId, originatorVersion: index, topic: "topic", state: "state".data(using: .utf8)!)
            try recorder.insertEvents([storedEvent])
        }
        
        // get the section of log.
        section = notificationLog["6,10"]
        XCTAssertEqual(section.items.count, 4)
        XCTAssertEqual(section.sectionId, "6,9")
        XCTAssertNil(section.nextId)
    }
}
