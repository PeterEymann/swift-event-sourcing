//
//  SnapshotTestCase.swift
//  
//
//  Created by Peter Eymann on 02/02/22.
//

import XCTest
@testable import EventSourcing

class SnapshotTestCase: XCTestCase {
    func testSnapshot() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        InjectedValues[\.aggregateRegistry] = registry
        let mapper = Mapper()
        // open an account
        let account = BankAccount.open(fullName: "Alice", emailAddress: "alice@example.com")
        // credit the account
        try account.appendTransaction(amount: 10)
        try account.appendTransaction(amount: 25)
        try account.appendTransaction(amount: 30)
        
        let snapshotStore = EventStore(recorder: InMemoryAggregateRecorder(), mapper: mapper)
        
        account.pendingEvents = []
        // take a snapshot and store it
        let snapshot = Snapshot.take(aggregate: account)
        try snapshotStore.put([snapshot])
        
        // get the snapshot
        let fetchedSnapShot = try snapshotStore.get(originatorId: account.id, desc: true, limit: 1)[0]
        var copy: BankAccount? = nil
        try fetchedSnapShot.mutate(obj: &copy)
        XCTAssertEqual(copy!.balance, 65)
    }
}
