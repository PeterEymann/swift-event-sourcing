//
//  PolicyTestCase.swift
//  
//
//  Created by Peter Eymann on 08/02/22.
//

import XCTest
@testable import EventSourcing

struct EmailNotificationState: AggregateState {
    let id: UUID
    var version: Int
    let createdOn: Date
    var modifiedOn: Date
    
    let to: String
    let subject: String
    let message: String
}

protocol EmailNotificationEvent: AggregateEvent {
    func apply(obj: EmailNotification)
}

extension EmailNotificationEvent {
    func apply<T>(obj: inout T) throws where T : Aggregate {
        if let account = obj as? EmailNotification {
            apply(obj: account)
        }
    }
    
    func apply(obj: EmailNotification) {}
}


class EmailNotification: GenericAggregate, Aggregate {
    typealias State = EmailNotificationState
    var state: EmailNotificationState
    var pendingEvents: [DomainEvent] = []
    override class var events: [DomainEvent.Type] {
        return [Created.self]
    }

    required init(state: EmailNotificationState) {
        self.state = state
    }
    
    convenience init(id: UUID, version: Int, timeStamp: Date, to: String, subject: String, message: String) {
        self.init(state: EmailNotificationState(
            id: id, version: version, createdOn: timeStamp, modifiedOn: timeStamp, to: to, subject: subject, message: message
        ))
    }
    
    struct Created: EmailNotificationEvent, AggregateCreatedEvent {
        var originatorTopic: String        
        let data: DomainEventData
        let to: String
        let subject: String
        let message: String

        func createAggregate() -> EmailNotification {
            return EmailNotification(
                id: self.originatorId,
                version: self.originatorVersion,
                timeStamp: self.timeStamp,
                to: self.to,
                subject: self.subject,
                message: self.message
            )
        }

        init(_ jsonDict: JSONDict) {
            data = DomainEventData(jsonDict)
            originatorTopic = jsonDict["originatorTopic"] as! String
            to = jsonDict["to"] as! String
            subject = jsonDict["subject"] as! String
            message = jsonDict["message"] as! String
        }
    }
    
    class public func create(to: String, subject: String, message: String) -> EmailNotification {
        return try! makeAggregate(eventType: Created.self, payload: [
            "to": to,
            "subject": subject,
            "message": message
        ])
    }
}


struct PolicyApp: HasPolicies {
    var policies: [DomainPolicy] = []
}


class PolicyTestCase: XCTestCase {
    func testPolicy() throws {
        let openedAccountPolicy = DomainPolicy(eventType: BankAccount.Opened.self, action: {
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
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        registry.addAggregate(topic: "EmailNotification", aggregateClass: EmailNotification.self)
        InjectedValues[\.aggregateRegistry] = registry
        var policies = PolicyApp()
        policies.addPolicy(openedAccountPolicy)
        let account = BankAccount.open(fullName: "Alice", emailAddress: "alice@example.com")
        let events = account.collect()
        let accountOpened = events[0]
        let tracking = Tracking(
            applicationName: "upstreamApp", notificationId: 5
        )
        var processEvent = ProcessEvent(tracking: tracking)
        policies.applyPolicies(accountOpened, processEvent: &processEvent)
        XCTAssertEqual(processEvent.events.count, 1)
        let event = processEvent.events[0]
        XCTAssert(type(of: event) == EmailNotification.Created.self)
        XCTAssertEqual(processEvent.tracking.notificationId, 5)
        XCTAssertEqual(processEvent.tracking.applicationName, "upstreamApp")
    }
}
