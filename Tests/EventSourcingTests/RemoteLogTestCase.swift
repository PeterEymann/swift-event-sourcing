//
//  RemoteLogTestCase.swift
//  
//
//  Created by Peter Eymann on 05/02/22.
//

import XCTest
@testable import EventSourcing

protocol BankAccountsAPI: NotificationLogAPI {
    func openAccount(_ body: Data) -> Data
}

struct BankAccountsAPIModels {
    struct OpenAccountJsonRequest: Codable {
        let fullName: String
        let emailAddress: String
    }

    struct OpenAccountJsonResponse: Codable {
        let accountId: UUID
    }
}

class BankAccountsRemoteAPI: ApplicationAdapter, BankAccountsAPI {
    typealias TApplication = BankAccounts
    
    let app: BankAccounts
    let log: NotificationLogView
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    
    init (app: BankAccounts) {
        self.app = app
        self.log = JSONNotificationLogView(log: self.app.log as! LocalNotificationLog)
    }
        
    func openAccount(_ body: Data) -> Data {
        let request = try! decoder.decode(BankAccountsAPIModels.OpenAccountJsonRequest.self, from: body)
        let r = BankAccountsAPIModels.OpenAccountJsonResponse(accountId: app.openAccount(fullName: request.fullName, emailAddress: request.emailAddress))
        return try! encoder.encode(r)
    }
    
    func getLogSection(sectionId: String) -> Data {
        return log.get(sectionId: sectionId)
    }
}

class BankAccountsJsonClient {
    let api: BankAccountsAPI
    let log: RemoteNotificationLog
    
    init (api: BankAccountsAPI) {
        self.api = api
        self.log = RemoteNotificationLog(api: self.api)
    }
    
    func openAccount(fullName: String, emailAddress: String) -> UUID {
        let request = try! JSONEncoder().encode(BankAccountsAPIModels.OpenAccountJsonRequest(fullName: fullName, emailAddress: emailAddress))
        let response = try! JSONDecoder().decode(BankAccountsAPIModels.OpenAccountJsonResponse.self, from: api.openAccount(request))
        return response.accountId
    }
}


class RemoteLogTestCase: XCTestCase {
    func testJSONNotificationLogView() throws {
        let app = BankAccounts()
        let view = JSONNotificationLogView(log: app.log as! LocalNotificationLog)
        let s = view.get(sectionId: "1,10")
        XCTAssertEqual(String(data: s, encoding: .utf8)!, "{\"items\":[]}")
    }
    
    func testApplicationAdapter() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        InjectedValues[\.aggregateRegistry] = registry

        let app = BankAccounts()
        let adapter = BankAccountsRemoteAPI(app: app)
        let json = "{\"fullName\":\"Alice\",\"emailAddress\":\"alice@example.com\"}".data(using: .utf8)!
        let msg = adapter.openAccount(json)
        let s = String(decoding: adapter.getLogSection(sectionId: "1,10"), as: UTF8.self)
        XCTAssert(s.contains("BankAccount.Opened"))
        let accountId1 = try JSONDecoder().decode(BankAccountsAPIModels.OpenAccountJsonResponse.self, from: msg).accountId
        // test remote log
        let remoteLog = RemoteNotificationLog(api: adapter)
        let section = remoteLog["1,10"]
        XCTAssertEqual(section.items.count, 1)
        let notification1 = section.items[0]
        XCTAssertEqual(notification1.originatorId, accountId1)
        XCTAssert(String(decoding: notification1.state, as: UTF8.self).contains("Alice"))
    }
    
    func testJsonClient() throws {
        var registry = AggregateRegistry()
        registry.addAggregate(topic: "BankAccount", aggregateClass: BankAccount.self)
        InjectedValues[\.aggregateRegistry] = registry

        let app = BankAccounts()
        let adapter = BankAccountsRemoteAPI(app: app)
        let client = BankAccountsJsonClient(api: adapter)
        let accountId1 = client.openAccount(fullName: "Alice", emailAddress: "alice@example.com")
        let accountId2 = client.openAccount(fullName: "Bob", emailAddress: "bob@example.com")
        let section = client.log["1,10"]
        XCTAssertEqual(section.items.count, 2)
        let notification1 = section.items[0]
        XCTAssertEqual(notification1.originatorId, accountId1)
        XCTAssert(String(decoding: notification1.state, as: UTF8.self).contains("Alice"))
        let notification2 = section.items[1]
        XCTAssertEqual(notification2.originatorId, accountId2)
        XCTAssert(String(decoding: notification2.state, as: UTF8.self).contains("Bob"))
    }
}
