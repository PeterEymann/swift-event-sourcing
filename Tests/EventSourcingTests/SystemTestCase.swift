//
//  SystemTestCase.swift
//  
//
//  Created by Peter Eymann on 09/02/22.
//

import XCTest
@testable import EventSourcing

final class NotFollowing: Application & HasName {
    static let name: String = "NotFollowing"
}

class SystemTestCase: XCTestCase {
    func testSystemTypeError() throws {
        XCTAssertThrowsError(_ = try System([[ProcessBankAccounts.self, NotFollowing.self]])) { error in
            XCTAssertEqual(error as! SystemErrors, SystemErrors.NotAFollowerClass(name: "NotFollowing"))
        }
    }
    
    func testSystem() throws {
        let system = try System([
            [ProcessBankAccounts.self, EmailNotifications.self]
        ])
        XCTAssertEqual(system.nodes.count, 2)
        XCTAssertEqual(system.edges.count, 1)
        XCTAssertEqual(system.edges[0].leader, "BankAccounts")
        XCTAssertEqual(system.edges[0].follower, "EmailNotifications")
    }
}
