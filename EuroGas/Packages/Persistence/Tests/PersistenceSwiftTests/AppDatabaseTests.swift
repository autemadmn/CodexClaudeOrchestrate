import XCTest
import CostCore
@testable import Persistence

final class AppDatabaseTests: XCTestCase {
    func testBootstrapCreatesExactlyOneOwnerAndUngroupedGroup() throws {
        let store = EuroGasStore(database: try AppDatabase.inMemory())
        XCTAssertEqual(try store.people().filter(\.isOwner).count, 1)
        XCTAssertEqual(try store.groups().filter(\.isUngrouped).count, 1)
    }

    func testCompleteEditDeletePreservesExplicitPayments() throws {
        let store = EuroGasStore(database: try AppDatabase.inMemory())
        let now = Date(timeIntervalSince1970: 1_725_000_000)
        let vehicleID = try store.configureVehicle(.init(displayName: "Coche", energyKind: "gasoline", consumptionPer100: 6, unitPrice: .init(milliEUR: 1_499)), now: now)
        let personID = try store.createPerson(name: "Carlos", now: now)
        let groupID = try store.createGroup(name: "Trabajo", memberIDs: [SystemIDs.owner, personID], now: now)
        let tripID = try store.startTrip(.init(vehicleID: vehicleID, consumptionPer100: 6, unitPrice: .init(milliEUR: 1_499), totalPeople: 2, splitRule: .everyone, groupID: groupID, participantIDs: [SystemIDs.owner, personID], startedAt: now))
        let state = ActiveTripState(tripID: TripID(tripID), sequence: 1, savedAt: now, phase: .tracking, lastAcceptedFix: nil, accumulator: .init(acceptedDistanceMeters: 100_000), lastMovementAt: now, unmeasuredIntervalFlag: false, liveActivityID: nil)
        try store.checkpoint(.init(tripID: tripID, state: state, energyCost: .init(cents: 899), estimatedEnergy: 6, movingSeconds: 3_600, pausedSeconds: 0))
        try store.completeTrip(.init(tripID: tripID, endedAt: now.addingTimeInterval(3_600), expenses: [.init(label: "Peaje", kind: "toll", amount: .init(cents: 250))], participantIDs: [SystemIDs.owner, personID]))
        let batch = try store.recordPayment(personID: personID, allocations: [(groupID, .init(cents: 100))], occurredAt: now.addingTimeInterval(4_000), note: nil)
        try store.editCompletedTrip(.init(tripID: tripID, endedAt: now.addingTimeInterval(3_600), expenses: [], participantIDs: [SystemIDs.owner, personID]))
        XCTAssertEqual(try store.balances().first?.balanceCents, 350)
        try store.deleteTrip(id: tripID)
        XCTAssertEqual(try store.balances().first?.balanceCents, -100)
        try store.undoPayment(batchID: batch)
        XCTAssertTrue(try store.balances().isEmpty)
    }

    func testBackupRoundTripPreservesBalancesAndRejectsInvalidInput() throws {
        let original = EuroGasStore(database: try AppDatabase.inMemory())
        let now = Date(timeIntervalSince1970: 1_725_000_000)
        _ = try original.configureVehicle(.init(displayName: "Eléctrico", energyKind: "bev", consumptionPer100: 18, unitPrice: .init(milliEUR: 200)), now: now)
        let data = try original.exportBackup(now: now)
        let restored = EuroGasStore(database: try AppDatabase.inMemory())
        try restored.importBackup(data)
        XCTAssertEqual(try restored.vehicles().map(\.displayName), ["Eléctrico"])
        XCTAssertThrowsError(try restored.importBackup(Data("{}".utf8)))
        XCTAssertEqual(try restored.vehicles().map(\.displayName), ["Eléctrico"])
    }
}
