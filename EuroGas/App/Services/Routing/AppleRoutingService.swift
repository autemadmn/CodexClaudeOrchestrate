import MapKit
import UIKit

@MainActor
final class AppleRoutingService: RoutingService {
    func route(_ request: RouteRequest) async throws -> [RouteSummary] {
        guard request.origin.localizedCaseInsensitiveCompare(request.destination) != .orderedSame else { throw RoutingError.samePlace }
        do {
            let origin = try await mapItem(named: request.origin)
            let destination = try await mapItem(named: request.destination)
            let directionsRequest = MKDirections.Request()
            directionsRequest.source = origin
            directionsRequest.destination = destination
            directionsRequest.transportType = .automobile
            let response = try await MKDirections(request: directionsRequest).calculate()
            guard !response.routes.isEmpty else { throw RoutingError.notFound }
            return response.routes.map { route in
                RouteSummary(id: String(route.hashValue), name: route.name, distanceMeters: route.distance, expectedSeconds: route.expectedTravelTime, hasTolls: route.hasTolls, destinationLatitude: destination.placemark.coordinate.latitude, destinationLongitude: destination.placemark.coordinate.longitude)
            }
        } catch let error as RoutingError { throw error }
        catch { throw RoutingError.network }
    }

    func availableNavigationApps() -> [NavigationApp] {
        [.appleMaps] + [.googleMaps, .waze].filter { app in
            guard let url = URL(string: app == .googleMaps ? "comgooglemaps://" : "waze://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    func openExternalNavigation(to route: RouteSummary, using app: NavigationApp) async throws {
        if app == .appleMaps {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: route.destinationLatitude, longitude: route.destinationLongitude)))
            item.name = route.name
            guard item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]) else { throw RoutingError.cannotOpenNavigation }
            return
        }
        var components = URLComponents()
        components.scheme = app == .googleMaps ? "comgooglemaps" : "waze"
        components.host = ""
        components.queryItems = app == .googleMaps
            ? [.init(name: "daddr", value: "\(route.destinationLatitude),\(route.destinationLongitude)"), .init(name: "directionsmode", value: "driving")]
            : [.init(name: "ll", value: "\(route.destinationLatitude),\(route.destinationLongitude)"), .init(name: "navigate", value: "yes")]
        guard let url = components.url, await UIApplication.shared.open(url) else {
            try await openExternalNavigation(to: route, using: .appleMaps)
            return
        }
    }

    private func mapItem(named text: String) async throws -> MKMapItem {
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = text
        guard let item = try await MKLocalSearch(request: request).start().mapItems.first else { throw RoutingError.notFound }
        return item
    }
}
