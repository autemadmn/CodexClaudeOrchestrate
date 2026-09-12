import XCTest
@testable import CostCore

final class TripStateMachineTests: XCTestCase {
    func testHappyPath() throws {
        var machine = TripStateMachine()
        try machine.apply(.start)
        try machine.apply(.firstFix)
        try machine.apply(.pause(.user))
        try machine.apply(.resume)
        try machine.apply(.finish)
        try machine.apply(.finishCommitted)
        XCTAssertEqual(machine.phase, .completed)
    }

    func testRepeatedStartIsRejected() throws {
        var machine = TripStateMachine()
        try machine.apply(.start)
        XCTAssertThrowsError(try machine.apply(.start))
    }

    func testInterruptedRecoveryNeedsFreshStart() throws {
        var machine = TripStateMachine(phase: .interrupted)
        XCTAssertEqual(try machine.apply(.recoverInterrupted), .starting)
    }
}
