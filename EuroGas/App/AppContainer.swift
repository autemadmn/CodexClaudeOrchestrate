import Foundation
import Persistence

@MainActor
final class AppContainer {
    let repository: AppRepository
    let location: LocationProvider
    let routing: RoutingService
    let purchaseAccess: PurchaseAccess
    let liveActivity: LiveActivityService
    let ledger: LedgerService
    let backup: BackupService
    let tripController: TripController
    let clock: any AppClock

    init(repository: AppRepository, location: LocationProvider, routing: RoutingService, purchaseAccess: PurchaseAccess, liveActivity: LiveActivityService, clock: any AppClock) {
        self.repository = repository; self.location = location; self.routing = routing; self.purchaseAccess = purchaseAccess; self.liveActivity = liveActivity; self.clock = clock
        ledger = LocalLedgerService(repository: repository, clock: clock)
        backup = LocalBackupService(repository: repository, clock: clock)
        tripController = TripController(repository: repository, location: location, liveActivity: liveActivity, clock: clock)
    }

    static func live() throws -> AppContainer {
        let baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppEnvironment.provisionalAppGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let database = try AppDatabase.open(at: baseURL.appendingPathComponent(AppEnvironment.databaseName))
        return AppContainer(repository: EuroGasStore(database: database), location: AppleLocationProvider(), routing: AppleRoutingService(), purchaseAccess: StoreKitPurchaseAccess(), liveActivity: ActivityKitLiveActivityService(), clock: SystemAppClock())
    }

    static func preview() -> AppContainer {
        let repository = EuroGasStore(database: try! AppDatabase.inMemory())
        let clock = FixedAppClock()
        _ = try? repository.configureVehicle(.init(displayName: "Coche de prueba", energyKind: "gasoline", consumptionPer100: 6.1, unitPrice: .init(milliEUR: 1_499)), now: clock.now)
        return AppContainer(repository: repository, location: ReplayLocationProvider(), routing: FakeRoutingService(), purchaseAccess: FakePurchaseAccess(), liveActivity: FakeLiveActivityService(), clock: clock)
    }
}
