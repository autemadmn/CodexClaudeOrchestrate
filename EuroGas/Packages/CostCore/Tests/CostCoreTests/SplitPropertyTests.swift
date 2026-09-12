import XCTest
@testable import CostCore

final class SplitPropertyTests: XCTestCase {
    func testDeterministicSplitProperties() {
        var state: UInt64 = 0xC0DEC0DE
        func next(_ upper: Int) -> Int { state = state &* 6364136223846793005 &+ 1442695040888963407; return Int((state >> 32) % UInt64(upper)) }
        for _ in 0..<1000 {
            let total = Int64(next(100001)), people = next(8) + 1
            for rule in [SplitRule.everyone, .passengersOnly] {
                if rule == .passengersOnly && people == 1 { continue }
                let a = SplitEngine.split(total: MoneyCents(cents: total), people: people, rule: rule)
                let b = SplitEngine.split(total: MoneyCents(cents: total), people: people, rule: rule)
                XCTAssertEqual(a, b)
                if total == 0 { XCTAssertTrue(a.shares.isEmpty) } else { XCTAssertEqual(a.shares.reduce(Int64(0)) { $0 + $1.cents }, total) }
                XCTAssertTrue(a.shares.allSatisfy { $0.cents >= 0 })
                if rule == .passengersOnly && !a.shares.isEmpty { XCTAssertEqual(a.shares[0], .zero) }
            }
        }
    }
}
