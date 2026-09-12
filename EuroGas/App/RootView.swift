import SwiftUI
import Persistence
import CostCore

@MainActor
final class AppModel: ObservableObject {
    @Published var vehicles: [VehicleRecord] = []
    @Published var people: [PersonRecord] = []
    @Published var groups: [GroupRecord] = []
    @Published var trips: [TripRecord] = []
    @Published var balances: [BalanceSummary] = []
    @Published var errorMessage: String?
    let container: AppContainer

    init(container: AppContainer) { self.container = container; refresh() }

    var needsOnboarding: Bool { vehicles.isEmpty }
    var isPro: Bool { if case .purchased = container.purchaseAccess.state { true } else { false } }

    func refresh() {
        do {
            vehicles = try container.repository.vehicles()
            people = try container.repository.people(includeArchived: false)
            groups = try container.repository.groups(includeArchived: false)
            trips = try container.repository.completedTrips()
            balances = try container.ledger.balances()
        } catch { errorMessage = error.localizedDescription }
    }

    func configureVehicle(name: String, energy: String, consumption: String, price: String) -> Bool {
        do {
            guard let consumptionDecimal = Decimal(string: consumption.replacingOccurrences(of: ",", with: ".")) else { throw PersistenceError.invalidState("Introduce un consumo válido.") }
            let unitPrice = try UnitPriceMilliEUR(parsing: price, locale: Locale(identifier: "es_ES"))
            _ = try container.repository.configureVehicle(.init(displayName: name, energyKind: energy, consumptionPer100: consumptionDecimal, unitPrice: unitPrice), now: container.clock.now)
            refresh(); return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
}

struct RootView: View {
    @StateObject private var model: AppModel
    let startupError: String?

    init(container: AppContainer, startupError: String? = nil) {
        _model = StateObject(wrappedValue: AppModel(container: container)); self.startupError = startupError
    }

    var body: some View {
        Group {
            if model.needsOnboarding {
                OnboardingView(model: model)
            } else {
                TabView {
                    DriveView(model: model).tabItem { Label("Conducir", systemImage: "car.fill") }
                    TripsView(model: model).tabItem { Label("Viajes", systemImage: "clock.arrow.circlepath") }
                    AccountsView(model: model).tabItem { Label("Cuentas", systemImage: "person.2.fill") }
                    SettingsView(model: model).tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                }
            }
        }
        .task { await model.container.purchaseAccess.refresh(); await model.container.tripController.recoverIfNeeded() }
        .alert("EuroGas", isPresented: Binding(get: { startupError != nil || model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Aceptar") { model.errorMessage = nil }
        } message: { Text(startupError ?? model.errorMessage ?? "") }
    }
}

#Preview { RootView(container: .preview()) }
