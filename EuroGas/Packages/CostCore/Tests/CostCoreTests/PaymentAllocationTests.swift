import XCTest
@testable import CostCore

final class PaymentAllocationTests: XCTestCase {
    func testSectionNineThreeAllocation() throws {
        let groups = [
            GroupPending(groupID: GroupID("Trabajo"), pending: MoneyCents(cents: 1_200), createdAt: Date(timeIntervalSince1970: 1), id: "1"),
            GroupPending(groupID: GroupID("Universidad"), pending: MoneyCents(cents: 800), createdAt: Date(timeIntervalSince1970: 2), id: "2")
        ]
        let allocation = try PaymentAllocationProposal.propose(amount: MoneyCents(cents: 1_500), pendingByGroup: groups)
        XCTAssertEqual(allocation.map { $0.amount.cents }, [1_200, 300])
        XCTAssertEqual(allocation.reduce(0) { $0 + $1.amount.cents }, 1_500)
        XCTAssertTrue(allocation.allSatisfy { !$0.groupID.rawValue.isEmpty })
        XCTAssertEqual(try PaymentAllocationProposal.propose(amount: MoneyCents(cents: 1_500), pendingByGroup: groups).dropFirst().first?.amount.cents, 300)
    }

    func testTypedErrors() {
        let groups = [GroupPending(groupID: GroupID("g"), pending: MoneyCents(cents: 1), createdAt: Date(), id: "g")]
        XCTAssertThrowsError(try PaymentAllocationProposal.propose(amount: MoneyCents(cents: 2), pendingByGroup: groups)) { XCTAssertEqual($0 as? PaymentAllocationError, .missingCreditGroup) }
        XCTAssertThrowsError(try PaymentAllocationProposal.propose(amount: .zero, pendingByGroup: groups)) { XCTAssertEqual($0 as? PaymentAllocationError, .nonPositiveAmount) }
    }
}
