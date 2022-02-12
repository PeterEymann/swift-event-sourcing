//
//  AggregateTestCase.swift
//  
//
//  Created by Peter Eymann on 24/01/22.
//

import XCTest
@testable import EventSourcing


protocol BankAccountEvent: AggregateEvent {
    func apply(obj: BankAccount)
}

extension BankAccountEvent {
    func apply<T>(obj: inout T) throws where T : Aggregate {
        if let account = obj as? BankAccount {
            apply(obj: account)
        }
    }
    
    func apply(obj: BankAccount) {}
}

struct BankAccountState: AggregateState {
    let id: UUID
    var version: Int
    let createdOn: Date
    var modifiedOn: Date
    
    var fullName: String
    var emailAddress: String
    var balance: Decimal = 0.0
    var overdraftLimit: Decimal = 0.0
    var isClosed = false
}

enum BankAccountError: Error, Equatable {
    case AccountClosed(accountId: UUID)
    case InsufficientFunds(accountId: UUID)
}

class BankAccount: GenericAggregate, Aggregate {
    typealias State = BankAccountState
    var pendingEvents: [DomainEvent] = []
    var state: State
    var fullName: String { self.state.fullName }
    var emailAddress: String { self.state.emailAddress }
    var balance: Decimal { self.state.balance }
    var overdraftLimit: Decimal { self.state.overdraftLimit }
    var isClosed: Bool { self.state.isClosed }

    override class var events: [DomainEvent.Type] {
        return [Opened.self, TransactionAppended.self, OverdraftLimitSet.self, Closed.self]
    }
        
    required init(state: BankAccountState) {
        self.state = state
    }

    convenience init(id: UUID, version: Int, timeStamp: Date, fullName: String, emailAddress: String) {
        self.init(state: BankAccountState(
            id: id, version: version, createdOn: timeStamp, modifiedOn: timeStamp, fullName: fullName, emailAddress: emailAddress
        ))
    }
            
    func checkAccountIsNotClosed() throws {
        if self.state.isClosed {
            throw BankAccountError.AccountClosed(accountId: self.id)
        }
    }
    
    func checkHasSufficientFunds(amount: Decimal) throws {
        if self.state.balance + amount < -self.state.overdraftLimit {
            throw BankAccountError.InsufficientFunds(accountId: self.id)
        }
    }

    struct Opened: BankAccountEvent, AggregateCreatedEvent {
        let originatorTopic: String
        let data: DomainEventData
        let fullName: String
        let emailAddress: String

        func createAggregate() -> BankAccount {
            return BankAccount(
                id: self.originatorId,
                version: self.originatorVersion,
                timeStamp: self.timeStamp,
                fullName: self.fullName,
                emailAddress: self.emailAddress
            )
        }
        
        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
            originatorTopic = jsonDict["originatorTopic"] as! String
            fullName = jsonDict["fullName"] as! String
            emailAddress = jsonDict["emailAddress"] as! String
        }
        
    }

    public class func open(fullName: String, emailAddress: String) -> BankAccount {
        // creates a new bank account object
        return try! makeAggregate(eventType: Opened.self, payload: [
            "fullName": fullName,
            "emailAddress": emailAddress
        ])
    }
    
    struct TransactionAppended: BankAccountEvent {
        let data: DomainEventData
        let amount: Decimal
        
        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
            amount = jsonDict["amount"] as! Decimal
        }
        
        func apply(obj: BankAccount) {
            obj.state.balance += self.amount
        }
    }

    func appendTransaction(amount: Decimal) throws {
        // appends a given amount as transaction on account
        // check not closed
        try self.checkAccountIsNotClosed()
        // check funds
        try self.checkHasSufficientFunds(amount: amount)
        try self.triggerEvent(TransactionAppended.self, for: self, payload: ["amount": amount])
    }
    
    struct OverdraftLimitSet: BankAccountEvent {
        typealias AggregateType = BankAccount
        let data: DomainEventData
        let limit: Decimal
        
        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
            limit = jsonDict["limit"] as! Decimal
        }
        
        func apply(obj: BankAccount) {
            obj.state.overdraftLimit = self.limit
        }
    }
    
    func setOverDraftLimit(overdraftLimit: Decimal) throws {
        assert(overdraftLimit > 0)
        try self.checkAccountIsNotClosed()
        try self.triggerEvent(OverdraftLimitSet.self, for: self, payload: ["limit": overdraftLimit])
    }
    
    struct Closed: BankAccountEvent {
        typealias AggregateType = BankAccount
        let data: DomainEventData
        
        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
        }
        
        func apply(obj: BankAccount) {
            obj.state.isClosed = true
        }
    }
    
    func close() throws {
        try self.triggerEvent(Closed.self, for: self)
    }
}


class BankAccountCopy: BankAccount {}


class AggregateRegistryFailuresTestCase: XCTestCase {
    var registry: AggregateRegistry = AggregateRegistry()
    
    func testGetTopicFailsWithTopicNotFound() throws {
        XCTAssertThrowsError(try registry.getTopic(for: BankAccount.self), "topic not found error has not been thrown") {
            error in XCTAssertEqual(error as? AggregateError, AggregateError.TopicNotFound)
        }
    }
    
    func testResolveFailsWithObjectNotFound() throws {
        XCTAssertThrowsError(try registry.resolveAggregate("invalid topic"), "aggregate not found error has not been thrown") {
            error in XCTAssertEqual(error as? AggregateError, AggregateError.ObjectNotFound("invalid topic"))
        }
    }
}

    
class AggregateRegistrySuccessTestCase: XCTestCase {
    func testAddTwoTimes() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccountCopy.self)
        let at = try registry.resolveAggregate("BankAccount")
        XCTAssert(at is BankAccountCopy.Type)
    }
    
    func testResolveSuccess() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        let at = try registry.resolveAggregate("BankAccount")
        XCTAssert(at is BankAccount.Type)
    }

    func testResolveEventSuccess() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        let at = try registry.resolveDomainEvent("BankAccount.Opened")
        XCTAssert(at is BankAccount.Opened.Type)
    }
    
    func testGetAggregateTopicSuccess() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        let topic = try registry.getTopic(for: BankAccount.self)
        XCTAssertEqual(topic, "BankAccount")
    }

    func testGetDomainEventTopicSuccess() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        let topic = try registry.getTopic(for: BankAccount.OverdraftLimitSet.self)
        XCTAssertEqual(topic, "BankAccount.OverdraftLimitSet")
    }

}

    
class AggregateTestCase: XCTestCase {
    func testBankAccountExampleAggregate() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        InjectedValues[\.aggregateRegistry] = registry
        let account = BankAccount.open(fullName: "Alice", emailAddress: "alice@example.com")
        XCTAssertEqual(account.fullName, "Alice")
        XCTAssertEqual(account.emailAddress, "alice@example.com")
        XCTAssertEqual(account.balance, 0.0)
        
        try account.appendTransaction(amount: 10.00)
        XCTAssertEqual(account.balance, 10.00)

        try account.appendTransaction(amount: 10.00)
        XCTAssertEqual(account.balance, 20.00)

        // debit the account
        try account.appendTransaction(amount: -15.00)
        XCTAssertEqual(account.balance, 5.00)

        // fail to debit account due to insufficient funds
        XCTAssertThrowsError(try account.appendTransaction(amount: -15.00), "Insufficient funds error not raised") {
            error in XCTAssertEqual(
                error as? BankAccountError, BankAccountError.InsufficientFunds(accountId: account.id)
            )
        }

        // increase thew overdraft limit
        try account.setOverDraftLimit(overdraftLimit: 100.00)
        try account.appendTransaction(amount: -15.00)
        XCTAssertEqual(account.balance, -10.00)

        try account.close()
        XCTAssertThrowsError(try account.appendTransaction(amount: 10.00), "Account closed error not thrown") {
            error in XCTAssertEqual(
                error as? BankAccountError, BankAccountError.AccountClosed(accountId: account.id)
            )
        }

        let pending = account.collect()
        XCTAssertEqual(pending.count, 7)
        XCTAssertEqual(account.pendingEvents.count, 0)        
    }
}
