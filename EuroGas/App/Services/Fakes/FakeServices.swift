import Foundation
import CostCore

@MainActor
final class ReplayLocationProvider: LocationProvider {
    var authorizationState: LocationAuthorizationState = .allowed
    private let fixes: [LocationFix]
    init(fixes: [LocationFix] = ReplayLocationProvider.cityDrive) { self.fixes = fixes }
    func requestAuthorization() async {}
    func startUpdates() -> AsyncStream<LocationFix> {
        AsyncStream { continuation in
            for fix in fixes { continuation.yield(fix) }
            continuation.finish()
        }
    }
    func stopUpdates() {}

    static let cityDrive: [LocationFix] = {
        let start = Date(timeIntervalSince1970: 1_725_000_000)
        return (0..<8).map { index in LocationFix(latitude: 39.4699 + Double(index) * 0.0004, longitude: -0.3763, horizontalAccuracy: 6, timestamp: start.addingTimeInterval(Double(index) * 5)) }
    }()
}

@MainActor
final class FakeRoutingService: RoutingService {
    var result: Result<[RouteSummary], Error> = .success([.init(id: "preview-route", name: "Ruta de prueba (fake)", distanceMeters: 12_400, expectedSeconds: 1_080, hasTolls: false, destinationLatitude: 39.57, destinationLongitude: -0.33)])
    func route(_ request: RouteRequest) async throws -> [RouteSummary] { try result.get() }
    func availableNavigationApps() -> [NavigationApp] { [.appleMaps] }
    func openExternalNavigation(to route: RouteSummary, using app: NavigationApp) async throws {}
}

@MainActor
final class FakePurchaseAccess: PurchaseAccess {
    var state: PurchaseState
    var displayPrice: String? = "3,99 € (prueba local)"
    init(state: PurchaseState = .free) { self.state = state }
    func refresh() async {}
    func purchase() async { state = .purchased }
    func restore() async { state = .purchased }
}

@MainActor
final class FakeLiveActivityService: LiveActivityService {
    private(set) var events: [String] = []
    func start(_ presentation: LiveTripPresentation) async throws -> String? { events.append("start"); return "fake-activity" }
    func update(_ presentation: LiveTripPresentation) async { events.append("update") }
    func end(_ presentation: LiveTripPresentation) async { events.append("end") }
    func recover(id: String?, presentation: LiveTripPresentation) async -> String? { events.append("recover"); return id ?? "fake-recovered" }
}
