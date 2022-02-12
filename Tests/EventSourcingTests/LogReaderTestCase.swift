//
//  LogReaderTestCase.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
//

import XCTest
@testable import EventSourcing

class LogReaderTestCase: XCTestCase {
    func testNotificationLogReader() throws {
        let recorder = InMemoryApplicationRecorder()
        let log = LocalNotificationLog(recorder: recorder)
        let reader = NotificationLogReader(log)
        var notifications = reader.read(start: 1)
        XCTAssertEqual(notifications.count, 0)
        
        // write 5 events
        let originatorId = UUID()
        for i in 1...5 {
            let storedEvent = StoredEvent(originatorId: originatorId, originatorVersion: i, topic: "topic", state: "state".data(using: .utf8)!)
            try recorder.insertEvents([storedEvent])
        }
        notifications = reader.read(start: 1)
        XCTAssertEqual(notifications.count, 5)
        notifications = reader.read(start: 2)
        XCTAssertEqual(notifications.count, 4)
        notifications = reader.read(start: 5)
        XCTAssertEqual(notifications.count, 1)
        notifications = reader.read(start: 6)
        XCTAssertEqual(notifications.count, 0)
    }
}
