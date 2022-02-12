//
//  ProcessTestCase.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
//

import XCTest
@testable import EventSourcing

final class ProcessBankAccounts: Application, Leads, BankAccountsApplication {
    public static let name: String = "BankAccounts"
    var followers: [Promptable] = []
    var policies: [DomainPolicy] = []
}

final class EmailNotifications: Follower, ProcessorApplication {
    public static let name: String = "EmailNotifications"
    var followers: [Promptable] = []
    
    required init() {
        super.init()
        policies = [
            DomainPolicy(eventType: BankAccount.Opened.self, action: {
                (event, processEvent) in
                if let bankAccountOpened = event as? BankAccount.Opened {
                    let notification = EmailNotification.create(
                        to: bankAccountOpened.emailAddress,
                        subject: "Your New Account",
                        message: "Dear \(bankAccountOpened.fullName)"
                    )
                    processEvent.collect(aggregates: [notification])
                }
            })
        ]
    }
}

class ProcessTestCase: XCTestCase {
    func testLeadersAndFollowers() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        registry.addAggregate(topic: "EmailNotification", aggregateClass: EmailNotification.self)
        InjectedValues[\.aggregateRegistry] = registry

        let accounts = ProcessBankAccounts()
        let notifications = EmailNotifications()
        XCTAssert(type(of: notifications.recorder) == InMemoryProcessRecorder.self)
        notifications.follow(name: "BankAccounts", log: accounts.log)

        XCTAssert(accounts.log["1,5"].items.isEmpty)
        XCTAssert(notifications.log["1,5"].items.isEmpty)

        _ = accounts.openAccount(fullName: "Alice", emailAddress: "alice@example.com")
        XCTAssertEqual(accounts.log["1,5"].items.count, 1)
        XCTAssert(notifications.log["1,5"].items.isEmpty)
        
        notifications.receivePrompt(leaderName: "BankAccounts")
        let section = notifications.log["1,5"]
        XCTAssertEqual(section.items.count, 1)
        let eventNotification = section.items[0]
        XCTAssertEqual(eventNotification.topic, "EmailNotification.Created")
        
        /// Due to the tracking of the position in the log that is being processed, prompting the email notifications application again will not generate another email notification.
        notifications.receivePrompt(leaderName: "BankAccounts")
        XCTAssertEqual(notifications.log["1,5"].items.count, 1)
        
        /// However, when the email notifications application is prompted after a second account is opened, so that a second event
        /// notification is presented by the notification log of the bank accounts application, then another email notification will be created.
        _ = accounts.openAccount(fullName: "Bob", emailAddress: "bob@example.com")
        notifications.receivePrompt(leaderName: "BankAccounts")
        XCTAssertEqual(notifications.log["1,5"].items.count, 2)
        
        /// Now, because we the ProcessBankAccounts application implements Leads, we can configure the bank accounts application to lead the email notifications application.
        accounts.lead(notifications)
        
        /// Now when we open a third account, the email notifications application will be automatically prompted to pull and process the notification log
        /// of the bank accounts application, and a new email notification will be automatically created.
        _ = accounts.openAccount(fullName: "Jane", emailAddress: "jane@example.com")
        XCTAssertEqual(notifications.log["1,5"].items.count, 3)
    }
}

