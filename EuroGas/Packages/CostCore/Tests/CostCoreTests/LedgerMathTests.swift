import XCTest
@testable import CostCore

final class LedgerMathTests: XCTestCase {
    func testDerivedValuesArePerGroup() {
        let work = GroupID("work")
        let university = GroupID("university")
        let me = PersonID("me")
        let owner = PersonID("owner")
        let entries = [
            LedgerEntry(id: "w", kind: .charge, debtorID: me, creditorID: owner, amountCents: MoneyCents(cents: 1_200), groupID: work, tripID: TripID("t1"), occurredAt: Date()),
            LedgerEntry(id: "u", kind: .charge, debtorID: me, creditorID: owner, amountCents: MoneyCents(cents: 800), groupID: university, tripID: TripID("t2"), occurredAt: Date()),
            LedgerEntry(id: "p", kind: .payment, debtorID: me, creditorID: owner, amountCents: MoneyCents(cents: 1_500), groupID: work, paymentBatchID: PaymentBatchID("b"), occurredAt: Date())
        ]
        XCTAssertEqual(LedgerMath.balance(entries: entries, person: me, group: work).cents, -300)
        XCTAssertEqual(LedgerMath.pending(entries: entries, person: me, group: work).cents, 0)
        XCTAssertEqual(LedgerMath.credit(entries: entries, person: me, group: work).cents, 300)
        XCTAssertEqual(LedgerMath.pending(entries: entries, person: me, group: university).cents, 800)
        XCTAssertEqual(LedgerMath.netAcrossGroups(entries: entries, person: me).cents, 500)
    }
}
