@preconcurrency import CoreLocation
import CostCore

@MainActor
final class AppleLocationProvider: NSObject, LocationProvider, @MainActor CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<LocationFix>.Continuation?
    private var authorizationContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.showsBackgroundLocationIndicator = true
    }

    var authorizationState: LocationAuthorizationState {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return manager.accuracyAuthorization == .reducedAccuracy ? .reducedAccuracy : .allowed
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .restricted
        }
    }

    func requestAuthorization() async {
        guard manager.authorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func startUpdates() -> AsyncStream<LocationFix> {
        if manager.accuracyAuthorization == .reducedAccuracy {
            manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "TripPreciseLocation")
        }
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable _ in Task { @MainActor in self.stopUpdates() } }
        }
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        continuation?.finish()
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            continuation?.yield(LocationFix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, horizontalAccuracy: location.horizontalAccuracy, speedMetersPerSecond: location.speed >= 0 ? location.speed : nil, timestamp: location.timestamp))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied { stopUpdates() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus != .notDetermined {
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        }
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            stopUpdates()
        }
    }
}
