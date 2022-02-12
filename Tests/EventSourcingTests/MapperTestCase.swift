//
//  MapperTestCase.swift
//  
//
//  Created by Peter Eymann on 31/01/22.
//

import XCTest
@testable import EventSourcing


class MapperTestCase: XCTestCase {
    func testMapper() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        InjectedValues[\.aggregateRegistry] = registry
        
        let mapper = Mapper()
        let originatorId = UUID()
        let event = BankAccount.TransactionAppended([
            "originatorId": originatorId,
            "originatorVersion": 1,
            "timeStamp": Date(),
            "amount": Decimal(10.00)
        ])
        let storedEvent = try mapper.fromDomainEvent(event)
        XCTAssertEqual(storedEvent.topic, "BankAccount.TransactionAppended")
        
        let newEvent = try mapper.toDomainEvent(storedEvent) as! BankAccount.TransactionAppended
        XCTAssertEqual(newEvent.amount, Decimal(10.00))
        XCTAssertEqual(newEvent.originatorId, originatorId)
    }
}
