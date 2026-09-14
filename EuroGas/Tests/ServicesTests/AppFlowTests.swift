import XCTest
import CostCore
import Persistence
@testable import EuroGas

@MainActor
final class AppFlowTests: XCTestCase {
    func testAppContainerUsesOneCompositionRoot() throws {
        let container = AppContainer.preview()
        XCTAssertFalse(try container.repository.vehicles().isEmpty)
        XCTAssertTrue(container.tripController === container.tripController)
    }

    func testVerticalFakeFlowCompletesOneTrip() async throws {
        let database = try AppDatabase.inMemory()
        let repository = EuroGasStore(database: database)
        let clock = FixedAppClock()
        let vehicleID = try repository.configureVehicle(.init(displayName: "Coche", energyKind: "gasoline", consumptionPer100: 6, unitPrice: .init(milliEUR: 1_499)), now: clock.now)
        let location = ReplayLocationProvider()
        let live = FakeLiveActivityService()
        let controller = TripController(repository: repository, location: location, liveActivity: live, clock: clock)
        await controller.start(.init(vehicleID: vehicleID, vehicleName: "Coche", consumptionPer100: 6, realWorldFactor: 1, unitPrice: .init(milliEUR: 1_499), people: 2, splitRule: .everyone, groupID: SystemIDs.ungrouped, participantIDs: [], origin: nil, destination: nil))
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertGreaterThan(controller.distanceMeters, 0)
        await controller.pause()
        await controller.resume()
        await controller.finish(expenses: [.init(label: "Parking", kind: "parking", amount: .init(cents: 200))], participantIDs: [])
        XCTAssertEqual(try repository.completedTrips().count, 1)
        XCTAssertEqual(live.events.first, "start")
        XCTAssertEqual(live.events.last, "end")
    }

    func testRoutingAndLiveActivityFakesAreDeterministic() async throws {
        let routing = FakeRoutingService()
        let routes = try await routing.route(.init(origin: "A", destination: "B"))
        XCTAssertEqual(routes.first?.distanceMeters, 12_400)
        XCTAssertEqual(routing.availableNavigationApps(), [.appleMaps])
        let live = FakeLiveActivityService()
        let presentation = LiveTripPresentation(tripID: "t", vehicleName: "Coche", startedAt: Date(), costCents: 100, distanceMeters: 1_000, totalPeople: 2, phase: "tracking")
        _ = try await live.start(presentation); await live.update(presentation); await live.end(presentation)
        XCTAssertEqual(live.events, ["start", "update", "end"])
    }

    func testStoreFakeCoversPurchaseAndRevocationWithoutTouchingData() async throws {
        let repository = EuroGasStore(database: try AppDatabase.inMemory())
        let access = FakePurchaseAccess(state: .free)
        let before = try repository.people().count
        await access.purchase()
        XCTAssertEqual(access.state, .purchased)
        access.state = .revoked
        XCTAssertEqual(try repository.people().count, before)
    }

    func testAppModelReflectsPurchaseAndRevocationImmediately() async throws {
        let repository = EuroGasStore(database: try AppDatabase.inMemory())
        let access = FakePurchaseAccess(state: .free)
        let container = AppContainer(repository: repository, location: ReplayLocationProvider(), routing: FakeRoutingService(), purchaseAccess: access, liveActivity: FakeLiveActivityService(), clock: FixedAppClock())
        let model = AppModel(container: container)
        await model.refreshPurchaseAccess()
        XCTAssertFalse(model.isPro)
        XCTAssertFalse(model.proGate.canReadRetainedHistory)
        await model.purchase()
        XCTAssertTrue(model.isPro)
        access.state = .revoked
        await model.refreshPurchaseAccess()
        XCTAssertFalse(model.isPro)
        XCTAssertEqual(model.purchaseState, .revoked)
        XCTAssertTrue(model.proGate.canReadRetainedHistory)
    }

    func testCheckpointRecoveryRestoresDistanceAndCanDiscard() async throws {
        let repository = EuroGasStore(database: try AppDatabase.inMemory())
        let clock = FixedAppClock()
        let vehicleID = try repository.configureVehicle(.init(displayName: "Coche", energyKind: "gasoline", consumptionPer100: 6, unitPrice: .init(milliEUR: 1_499)), now: clock.now)
        let tripID = try repository.startTrip(.init(vehicleID: vehicleID, consumptionPer100: 6, unitPrice: .init(milliEUR: 1_499), totalPeople: 1, splitRule: .everyone, startedAt: clock.now))
        let snapshot = GPSAccumulatorSnapshot(acceptedDistanceMeters: 4_200, estimatedGapDistanceMeters: 0, rejectedFixCount: 1, unmeasuredIntervalCount: 1)
        let active = ActiveTripState(tripID: TripID(tripID), sequence: 3, savedAt: clock.now, phase: .tracking, lastAcceptedFix: nil, accumulator: snapshot, lastMovementAt: clock.now, unmeasuredIntervalFlag: true, liveActivityID: "old-activity")
        try repository.checkpoint(.init(tripID: tripID, state: active, energyCost: .init(cents: 38), estimatedEnergy: 0.25, movingSeconds: 240, pausedSeconds: 12))

        let live = FakeLiveActivityService()
        let controller = TripController(repository: repository, location: ReplayLocationProvider(), liveActivity: live, clock: clock)
        await controller.recoverIfNeeded()
        XCTAssertEqual(controller.phase, .interrupted)
        XCTAssertEqual(controller.distanceMeters, 4_200, accuracy: 0.001)
        XCTAssertEqual(live.events, ["recover"])

        await controller.discardRecovered()
        XCTAssertEqual(controller.phase, .idle)
        XCTAssertNil(try repository.activeTrip())
        XCTAssertEqual(live.events.last, "end")
    }

    func testBackupServiceRejectsInvalidBeforeMutation() throws {
        let repository = EuroGasStore(database: try AppDatabase.inMemory())
        let service = LocalBackupService(repository: repository, clock: FixedAppClock())
        XCTAssertThrowsError(try service.preview(Data("not-json".utf8)))
        XCTAssertEqual(try repository.people().filter(\.isOwner).count, 1)
    }
}
