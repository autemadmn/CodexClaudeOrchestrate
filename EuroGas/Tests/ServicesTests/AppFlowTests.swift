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

    func testBackupServiceRejectsInvalidBeforeMutation() throws {
        let repository = EuroGasStore(database: try AppDatabase.inMemory())
        let service = LocalBackupService(repository: repository, clock: FixedAppClock())
        XCTAssertThrowsError(try service.preview(Data("not-json".utf8)))
        XCTAssertEqual(try repository.people().filter(\.isOwner).count, 1)
    }
}
