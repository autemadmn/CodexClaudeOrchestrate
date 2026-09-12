import XCTest
@testable import CostCore

final class AccountingPeriodTests: XCTestCase {
    private let madrid = TimeZone(identifier: "Europe/Madrid")!
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testBoundsAndDerivedMonthlyStatement() throws {
        let person = PersonID("me")
        let owner = PersonID("owner")
        let group = GroupID("g")
        let entries = [
            LedgerEntry(id: "opening", kind: .charge, debtorID: person, creditorID: owner, amountCents: MoneyCents(cents: 100), groupID: group, tripID: TripID("old"), occurredAt: date("2026-01-31T23:00:00Z")),
            LedgerEntry(id: "charge", kind: .charge, debtorID: person, creditorID: owner, amountCents: MoneyCents(cents: 1_200), groupID: group, tripID: TripID("new"), occurredAt: date("2026-02-15T12:00:00Z")),
            LedgerEntry(id: "payment", kind: .payment, debtorID: person, creditorID: owner, amountCents: MoneyCents(cents: 300), groupID: group, paymentBatchID: PaymentBatchID("p"), occurredAt: date("2026-02-20T12:00:00Z"))
        ]
        let bounds = try AccountingPeriod.bounds(forMonth: "2026-02", in: madrid)
        XCTAssertLessThan(bounds.start, bounds.end)
        let statement = try MonthlyStatement(entries: entries, person: person, forMonth: "2026-02", in: madrid)
        XCTAssertEqual(statement.opening.cents, 100)
        XCTAssertEqual(statement.charges.cents, 1_200)
        XCTAssertEqual(statement.payments.cents, 300)
        XCTAssertEqual(statement.closing.cents, 1_000)
        XCTAssertEqual(try MonthlyStatement(entries: entries, person: person, forMonth: "2026-03", in: madrid).closing, .zero)
    }

    func testDSTMonthStartsAreLocalMidnights() throws {
        for month in ["2026-03", "2026-10"] {
            let bounds = try AccountingPeriod.bounds(forMonth: month, in: madrid)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = madrid
            XCTAssertEqual(calendar.component(.hour, from: bounds.start), 0)
            XCTAssertEqual(calendar.component(.minute, from: bounds.start), 0)
        }
    }

    func testInvalidMonthIsTyped() {
        XCTAssertThrowsError(try AccountingPeriod.bounds(forMonth: "2026-13", in: madrid)) { error in
            XCTAssertEqual(error as? AccountingPeriodError, .invalidMonth)
        }
    }
}
