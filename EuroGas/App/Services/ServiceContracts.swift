import Foundation
import CostCore
import Persistence

enum LocationAuthorizationState: String, Sendable { case notDetermined, allowed, reducedAccuracy, denied, restricted }

@MainActor
protocol LocationProvider: AnyObject {
    var authorizationState: LocationAuthorizationState { get }
    func requestAuthorization() async
    func startUpdates() -> AsyncStream<LocationFix>
    func stopUpdates()
}

struct RouteRequest: Equatable, Sendable { let origin: String; let destination: String }
struct RouteSummary: Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let distanceMeters: Double
    let expectedSeconds: TimeInterval
    let hasTolls: Bool?
    let destinationLatitude: Double
    let destinationLongitude: Double
}

enum NavigationApp: String, CaseIterable, Identifiable, Sendable {
    case appleMaps, googleMaps, waze
    var id: String { rawValue }
    var title: String { switch self { case .appleMaps: "Apple Maps"; case .googleMaps: "Google Maps"; case .waze: "Waze" } }
}

enum RoutingError: Error, LocalizedError { case samePlace, notFound, network, cannotOpenNavigation
    var errorDescription: String? { switch self { case .samePlace: "El origen y el destino coinciden. Puedes empezar un viaje libre."; case .notFound: "No se ha encontrado una ruta."; case .network: "No hay conexión para planificar. Puedes empezar sin destino."; case .cannotOpenNavigation: "No se pudo abrir la navegación externa." } }
}

@MainActor
protocol RoutingService: AnyObject {
    func route(_ request: RouteRequest) async throws -> [RouteSummary]
    func availableNavigationApps() -> [NavigationApp]
    func openExternalNavigation(to route: RouteSummary, using app: NavigationApp) async throws
}

enum PurchaseState: Equatable, Sendable { case unknown, free, purchasing, purchased, pending, revoked, unavailable(String) }
@MainActor
protocol PurchaseAccess: AnyObject {
    var state: PurchaseState { get }
    var displayPrice: String? { get }
    func refresh() async
    func purchase() async
    func restore() async
}

struct LiveTripPresentation: Equatable, Sendable {
    let tripID: String
    let vehicleName: String
    let startedAt: Date
    let costCents: Int64
    let distanceMeters: Double
    let totalPeople: Int
    let phase: String
}

@MainActor
protocol LiveActivityService: AnyObject {
    func start(_ presentation: LiveTripPresentation) async throws -> String?
    func update(_ presentation: LiveTripPresentation) async
    func end(_ presentation: LiveTripPresentation) async
}

protocol AppRepository: AnyObject, Sendable {
    func configureVehicle(_ setup: VehicleSetup, now: Date) throws -> String
    func vehicles() throws -> [VehicleRecord]
    func drivingConfiguration(vehicleID: String) throws -> DrivingConfiguration
    func people(includeArchived: Bool) throws -> [PersonRecord]
    func groups(includeArchived: Bool) throws -> [GroupRecord]
    func completedTrips() throws -> [TripRecord]
    func createPerson(name: String, emoji: String?, now: Date) throws -> String
    func createGroup(name: String, memberIDs: [String], now: Date) throws -> String
    func startTrip(_ request: TripStartRequest) throws -> String
    func checkpoint(_ checkpoint: TripCheckpoint) throws
    func activeTripState() throws -> ActiveTripState?
    func completeTrip(_ completion: TripCompletion) throws
    func editCompletedTrip(_ completion: TripCompletion) throws
    func deleteTrip(id: String) throws
    func recordPayment(personID: String, allocations: [(groupID: String, amount: MoneyCents)], occurredAt: Date, note: String?) throws -> String
    func undoPayment(batchID: String) throws
    func balances() throws -> [BalanceSummary]
    func monthlyStatement(personID: String, month: String) throws -> MonthlyStatement
    func exportBackup(now: Date) throws -> Data
    func importBackup(_ data: Data) throws
    func exportCSV() throws -> CSVExport
}

extension EuroGasStore: AppRepository {}
