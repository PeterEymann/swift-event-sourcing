//
//  RepositoryTestCase.swift
//  
//
//  Created by Peter Eymann on 02/02/22.
//

import XCTest
@testable import EventSourcing


class RepositoryTestCase: XCTestCase {
    func testRepository() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        InjectedValues[\.aggregateRegistry] = registry
        let mapper = Mapper()
        let eventStore = EventStore(recorder: InMemoryApplicationRecorder(), mapper: mapper)
        let snapshotStore = EventStore(recorder: InMemoryAggregateRecorder(), mapper: mapper)
        let repository = Repository(eventSore: eventStore, snapshotStore: snapshotStore)
        
        // open a bank account
        var account = BankAccount.open(fullName: "Alice", emailAddress: "alice@example.com")
        let account_id = account.id
        
        // credit the account
        try account.appendTransaction(amount: 10)
        try account.appendTransaction(amount: 25)
        try account.appendTransaction(amount: 30)
        
        // collect pending events
        let pending = account.collect()
        
        // store pending events
        try eventStore.put(pending)
        
        // now we can access the bank account using the repository
        account = try repository.get(aggregateId: account_id)
        
        // check the account has the correct state values
        XCTAssertEqual(account.id, account_id)
        XCTAssertEqual(account.balance, 65)
        
        // create a snapshot
        let snapshot = Snapshot.take(aggregate: account)
        try snapshotStore.put([snapshot])
        
        // get aggregate (now uses snapshot)
        account = try repository.get(aggregateId: account_id)
        XCTAssertEqual(account.balance, 65)
        
        // continue to use the account and store subsequent domain events
        try account.appendTransaction(amount: 10)
        try eventStore.put(account.collect())
        
        // reconstruct aggregate from snapshot and domain events
        account = try repository.get(aggregateId: account_id)
        XCTAssertEqual(account.balance, 75)
        
        // we can now get old versions of the bank account
        // reconstruct version 1
        account = try repository.get(aggregateId: account_id, version: 1)
        XCTAssertEqual(account.balance, 0)

        // reconstruct version 2
        account = try repository.get(aggregateId: account_id, version: 2)
        XCTAssertEqual(account.balance, 10)

        // reconstruct version 3
        account = try repository.get(aggregateId: account_id, version: 3)
        XCTAssertEqual(account.balance, 35)
        
        // should throw an error if the aggregate is not found
        XCTAssertThrowsError(account = try repository.get(aggregateId: UUID())) {
            error in XCTAssertEqual(error as! RepositoryErrors, RepositoryErrors.AggregateNotFound)
        }
        
        // should throw an error if changes are made to a historic version
        account = try repository.get(aggregateId: account_id, version: 3)
        try account.appendTransaction(amount: 10)
        XCTAssertThrowsError(try eventStore.put(account.collect())) {
            error in XCTAssertEqual(error as! RecorderError, RecorderError.IntegrityError)
        }
    }
}
