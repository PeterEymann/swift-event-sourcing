//
//  EventStoreTestCase.swift
//  
//
//  Created by Peter Eymann on 01/02/22.
//

import XCTest
@testable import EventSourcing



class EventStoreTestCase: XCTestCase {
    func testExample() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        InjectedValues[\.aggregateRegistry] = registry
        let mapper = Mapper()
        let recorder = InMemoryApplicationRecorder()
        let store = EventStore(recorder: recorder, mapper: mapper)
        let account = BankAccount.open(fullName: "Alice", emailAddress: "alice@example.com")
        try account.appendTransaction(amount: 10.00)
        try account.appendTransaction(amount: 25.00)
        try account.appendTransaction(amount: 30.00)
        let pending = account.collect()
        try store.put(pending)
        let domainEvents = try store.get(originatorId: account.id)
        var newAccount: BankAccount? = nil
        for de in domainEvents {
            if let aggregateEvent = de as? AggregateEvent {
                try aggregateEvent.mutate(obj: &newAccount)
            }
        }
        XCTAssertEqual(newAccount!.id, account.id)
        XCTAssertEqual(newAccount!.state.balance, 65.00)
    }
}
