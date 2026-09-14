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
    @Published private(set) var purchaseState: PurchaseState = .unknown
    @Published private(set) var purchaseDisplayPrice: String?
    @Published var errorMessage: String?
    let container: AppContainer

    init(container: AppContainer) { self.container = container; refresh() }

    var needsOnboarding: Bool { vehicles.isEmpty }
    var proGate: ProGate { ProGate(state: purchaseState) }
    var isPro: Bool { proGate.canCreateNamedAccountingData }
    var visibleTrips: [TripRecord] {
        if proGate.canReadRetainedHistory { return trips }
        guard let range = try? FreeWindow.visibleRange(now: container.clock.now, in: AppEnvironment.accountingTimeZone) else { return [] }
        let formatter = ISO8601DateFormatter()
        return trips.filter { trip in
            guard let startedAt = formatter.date(from: trip.startedAt) else { return false }
            return startedAt >= range.start && startedAt <= range.end
        }
    }

    func refresh() {
        do {
            vehicles = try container.repository.vehicles()
            people = try container.repository.people(includeArchived: false)
            groups = try container.repository.groups(includeArchived: false)
            trips = try container.repository.completedTrips()
            balances = try container.ledger.balances()
        } catch { errorMessage = error.localizedDescription }
    }

    func refreshPurchaseAccess() async {
        await container.purchaseAccess.refresh()
        syncPurchaseAccess()
    }

    func purchase() async {
        await container.purchaseAccess.purchase()
        syncPurchaseAccess()
    }

    func restorePurchases() async {
        await container.purchaseAccess.restore()
        syncPurchaseAccess()
    }

    private func syncPurchaseAccess() {
        purchaseState = container.purchaseAccess.state
        purchaseDisplayPrice = container.purchaseAccess.displayPrice
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

    init(container: AppContainer) { _model = StateObject(wrappedValue: AppModel(container: container)) }

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
        .task { await model.refreshPurchaseAccess(); await model.container.tripController.recoverIfNeeded() }
        .alert("EuroGas", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Aceptar") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

#Preview { RootView(container: .preview()) }
