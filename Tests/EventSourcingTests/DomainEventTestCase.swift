//
//  DomainEventTests.swift
//  
//
//  Created by Peter Eymann on 24/01/22.
//

import XCTest
@testable import EventSourcing


struct AccountOpened: DomainEvent {
    let data: DomainEventData
    let fullName: String

    init(_ jsonDict: JSONDict) {
        self.data = DomainEventData(jsonDict)
        self.fullName = jsonDict["fullName"] as! String
    }
        
    var description: String {
        "Account opened for \(self.fullName)"
    }
}

struct FullNameUpdated: DomainEvent {
    let data: DomainEventData
    let fullName: String

    init(_ jsonDict: JSONDict) {
        self.data = DomainEventData(jsonDict)
        self.fullName = jsonDict["fullName"] as! String
    }

    var description: String {
        return "Name changed to '\(self.fullName)'"
    }
}

struct AccountClosed: DomainEvent {
    let data: DomainEventData
    
    init(_ jsonDict: JSONDict) {
        self.data = DomainEventData(jsonDict)
    }
}


class DomainEventTestCase: XCTestCase {
    func testExampleDomainEvents() throws {
        // create some sample domain events
        let originatorId = UUID()
        let event1 = AccountOpened([
            "originatorId": originatorId,
            "originatorVersion": 1,
            "timeStamp": Date(),
            "fullName": "Alice"
        ])
        XCTAssert(event1.fullName == "Alice")
        XCTAssert(event1.originatorId == originatorId)
        XCTAssert(event1.originatorVersion == 1)
        XCTAssert(event1.description == "Account opened for Alice")
        
        let event2 = FullNameUpdated([
            "originatorId": originatorId,
            "originatorVersion": 2,
            "timeStamp": Date(),
            "fullName": "Bob"
        ])
        XCTAssert(event2.fullName == "Bob")
        XCTAssert(event2.originatorVersion == 2)
        XCTAssert(event2.description == "Name changed to 'Bob'")

        let firedAt = Date()
        let event3 = AccountClosed([
            "originatorId": originatorId,
            "originatorVersion": 3,
            "timeStamp": Date(),
        ])
        XCTAssert(event3.description == "DomainEvent #3 for \(originatorId) fired at \(firedAt)")
    }
}
