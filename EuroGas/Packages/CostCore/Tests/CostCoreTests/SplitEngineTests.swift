import XCTest
@testable import CostCore

final class SplitEngineTests: XCTestCase {
    func testCanonicalSplits() {
        XCTAssertEqual(try! SplitEngine.split(total: MoneyCents(cents: 3420), people: 7, rule: .everyone).shares.map(\.cents), [492, 488, 488, 488, 488, 488, 488])
        XCTAssertEqual(try! SplitEngine.split(total: MoneyCents(cents: 3420), people: 4, rule: .passengersOnly).shares.map(\.cents), [0, 1140, 1140, 1140])
        XCTAssertEqual(try! SplitEngine.split(total: MoneyCents(cents: 1000), people: 4, rule: .passengersOnly).shares.map(\.cents), [0, 334, 333, 333])
        XCTAssertEqual(try! SplitEngine.split(total: MoneyCents(cents: 399), people: 4, rule: .everyone).shares.map(\.cents), [102, 99, 99, 99])
        XCTAssertEqual(try! SplitEngine.split(total: MoneyCents(cents: 400), people: 4, rule: .everyone).shares.map(\.cents), [100, 100, 100, 100])
    }

    func testZeroProducesNoSeats() {
        XCTAssertTrue(try! SplitEngine.split(total: .zero, people: 4, rule: .everyone).shares.isEmpty)
    }

    func testInvalidParticipantCountsThrowTypedErrors() {
        for people in [0, 9] {
            XCTAssertThrowsError(try SplitEngine.split(total: .zero, people: people, rule: .everyone)) { error in
                XCTAssertEqual(error as? CostCoreError, .participantCountOutOfRange(people))
            }
        }
    }

    func testPassengersOnlyOnePersonThrowsEvenForZeroTotal() {
        XCTAssertThrowsError(try SplitEngine.split(total: .zero, people: 1, rule: .passengersOnly)) { error in
            XCTAssertEqual(error as? CostCoreError, .passengersOnlyWithoutPassengers)
        }
    }

    func testNegativeTotalThrowsTypedError() {
        XCTAssertThrowsError(try SplitEngine.split(total: MoneyCents(cents: -1), people: 2, rule: .everyone)) { error in
            XCTAssertEqual(error as? CostCoreError, .negativeTotal)
        }
    }
}
