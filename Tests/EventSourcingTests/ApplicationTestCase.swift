//
//  ApplicationTestCase.swift
//  
//
//  Created by Peter Eymann on 04/02/22.
//

import XCTest
@testable import EventSourcing

enum BankAccountsErrors: Error {
    case AccountNotFound(accountId: UUID)
}

protocol BankAccountsApplication: Application {
    func openAccount(fullName: String, emailAddress: String) -> UUID
    func creditAccount(accountId: UUID, amount: Decimal) throws
    func debitAccount(accountId: UUID, amount: Decimal) throws
    func getBalance(accountId: UUID) throws -> Decimal
    func getAccount(accountId: UUID) throws -> BankAccount
}

extension BankAccountsApplication {
    func openAccount(fullName: String, emailAddress: String) -> UUID {
        let account = BankAccount.open(fullName: fullName, emailAddress: emailAddress)
        try! save(account)
        return account.id
    }
    
    func creditAccount(accountId: UUID, amount: Decimal) throws {
        let account = try getAccount(accountId: accountId)
        try account.appendTransaction(amount: amount)
        try! save(account)
    }
    
    func debitAccount(accountId: UUID, amount: Decimal) throws {
        let account = try getAccount(accountId: accountId)
        try account.appendTransaction(amount: -amount)
        try! save(account)
    }
    
    func getBalance(accountId: UUID) throws -> Decimal {
        let account = try getAccount(accountId: accountId)
        return account.balance
    }
    
    func getAccount(accountId: UUID) throws -> BankAccount {
        guard let aggregate: BankAccount = try? repository.get(aggregateId: accountId) else {
            throw BankAccountsErrors.AccountNotFound(accountId: accountId)
        }
        return aggregate
    }
}

final class BankAccounts: Application, BankAccountsApplication {
}


class ApplicationTestCase: XCTestCase {
    func testBankAccountsApp() throws {
        let app = BankAccounts()
        let section = app.log["0,10"]
        XCTAssertEqual(section.items.count, 0)
        let accountId = app.openAccount(fullName: "Alice", emailAddress: "alice@example.com")
        XCTAssertEqual(try app.getBalance(accountId: accountId), 0)
        XCTAssertEqual(app.log["0,10"].items.count, 1)
        try app.creditAccount(accountId: accountId, amount: 10)
        try app.creditAccount(accountId: accountId, amount: 25)
        try app.creditAccount(accountId: accountId, amount: 30)
        XCTAssertEqual(app.log["0,10"].items.count, 4)
        XCTAssertEqual(try app.getBalance(accountId: accountId), 65)
        try app.debitAccount(accountId: accountId, amount: 35)
        XCTAssertEqual(try app.getBalance(accountId: accountId), 30)
        XCTAssertThrowsError(try app.debitAccount(accountId: accountId, amount: 100)) {
            error in XCTAssertEqual(error as? BankAccountError, BankAccountError.InsufficientFunds(accountId: accountId))
        }
    }
}
