//
//  RunnerTestCase.swift
//  
//
//  Created by Peter Eymann on 09/02/22.
//

import XCTest
@testable import EventSourcing

class RunnerTestCase: XCTestCase {
    func testSingleThreadedRunner() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        registry.addAggregate(topic: "EmailNotification", aggregateClass: EmailNotification.self)
        InjectedValues[\.aggregateRegistry] = registry

        let system = try System([
            [ProcessBankAccounts.self, EmailNotifications.self]
        ])
        let runner = SingleThreadedRunner(system: system)
        try runner.start()
        /// The BankAccounts application is just an Application so it will be using an
        /// ApplicationRecorder which doesn’t have tracking records. The EmailNotifications
        /// application is a ProcessApplication and so it will be using a ProcessRecorder.
        ///
        /// We can get hold of the application objects that have been constructed by the system using the get() method.
        /// Passing in the application class returns the application instance.
        let accounts = runner.get(ProcessBankAccounts.self)
        let notifications = runner.get(EmailNotifications.self)
        /// At first, the bank accounts and email notifications applications have an empty notification log.
        XCTAssert(accounts.log["1,10"].items.isEmpty)
        XCTAssert(notifications.log["1,10"].items.isEmpty)
        /// So let’s open a bank account, using the open_account() method of the BankAccounts application.
        let accountId = accounts.openAccount(fullName: "Alice", emailAddress: "alice@example.com")
        XCTAssertEqual(try accounts.getBalance(accountId: accountId), 0)
        XCTAssertEqual(accounts.log["1,10"].items.count, 1)
        XCTAssertEqual(notifications.log["1,10"].items.count, 1)
        let eventNotification = notifications.log["1,10"].items[0]
        XCTAssertTrue(eventNotification.topic.hasSuffix("EmailNotification.Created"))
        let emailNotification: EmailNotification = try notifications.repository.get(aggregateId: eventNotification.originatorId)
        XCTAssertEqual(emailNotification.state.subject, "Your New Account")
    }
}
