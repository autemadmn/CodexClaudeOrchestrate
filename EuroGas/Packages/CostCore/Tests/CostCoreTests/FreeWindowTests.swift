import XCTest
@testable import CostCore

final class FreeWindowTests: XCTestCase {
    func testStartsAtLocalMidnightAndMonthlyTotalsRetainOlderEntries() throws {
        let zone = TimeZone(identifier: "Europe/Madrid")!
        let now = ISO8601DateFormatter().date(from: "2026-05-10T12:00:00Z")!
        let range = try FreeWindow.visibleRange(now: now, in: zone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        XCTAssertEqual(calendar.component(.hour, from: range.start), 0)
        XCTAssertEqual(calendar.dateComponents([.day], from: range.start, to: now).day, 29)
        let person = PersonID("me")
        let owner = PersonID("owner")
        let group = GroupID("g")
        let old = LedgerEntry(id: "old", kind: .charge, debtorID: person, creditorID: owner, amountCents: MoneyCents(cents: 500), groupID: group, tripID: TripID("t"), occurredAt: ISO8601DateFormatter().date(from: "2026-04-05T12:00:00Z")!)
        let monthly = try MonthlyStatement(entries: [old], person: person, forMonth: "2026-04", in: zone)
        XCTAssertEqual(monthly.charges.cents, 500)
        XCTAssertFalse((range.start...range.end).contains(old.occurredAt))
    }
}
