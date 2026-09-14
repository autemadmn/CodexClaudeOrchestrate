import SwiftUI
import CostCore
import Persistence

struct DriveView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var trip: TripController
    @State private var destination = ""
    @State private var origin = "Mi ubicación"
    @State private var people = 1
    @State private var passengersOnly = false
    @State private var route: RouteSummary?
    @State private var planning = false
    @State private var manualExpense = ""
    @State private var showSummary = false
    @State private var useNamedParticipants = false
    @State private var selectedGroupID = SystemIDs.ungrouped
    @State private var selectedParticipantIDs: Set<String> = []

    init(model: AppModel) { self.model = model; _trip = ObservedObject(wrappedValue: model.container.tripController) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if trip.phase == .idle { idleCard } else { activeCard }
                    if let error = trip.lastError { Text(error).foregroundStyle(.orange).padding().accessibilityLabel("Aviso: \(error)") }
                }.padding()
            }
            .navigationTitle("Conducir")
            .sheet(isPresented: $showSummary) { summarySheet }
        }
    }

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("¿Dónde vas?").font(.title2.bold())
            TextField("Origen", text: $origin).textFieldStyle(.roundedBorder)
            TextField("Destino opcional", text: $destination).textFieldStyle(.roundedBorder)
            Button(planning ? "Buscando ruta…" : "Planificar") { Task { await plan() } }.disabled(destination.isEmpty || planning)
            if let route {
                Text("\(route.name) · \(route.distanceMeters / 1000, specifier: "%.1f") km")
                Menu("Abrir navegación") {
                    ForEach(model.container.routing.availableNavigationApps()) { app in
                        Button(app.title) { Task { try? await model.container.routing.openExternalNavigation(to: route, using: app) } }
                    }
                }
            }
            if model.isPro {
                Toggle("Usar personas y cuentas", isOn: $useNamedParticipants)
                if useNamedParticipants {
                    Picker("Grupo", selection: $selectedGroupID) { ForEach(model.groups) { Text($0.name).tag($0.id) } }
                    ForEach(model.people.filter { !$0.isOwner }) { person in
                        Toggle(person.name, isOn: Binding(get: { selectedParticipantIDs.contains(person.id) }, set: { value in if value { selectedParticipantIDs.insert(person.id) } else { selectedParticipantIDs.remove(person.id) }; people = min(8, selectedParticipantIDs.count + 1) }))
                    }
                    Text("Yo (conductor) siempre ocupa la posición 0.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if !useNamedParticipants { Stepper("Personas: \(people)", value: $people, in: 1...8) }
            Toggle("Sólo pagan los pasajeros", isOn: $passengersOnly).disabled(people == 1)
            Button(destination.isEmpty ? "Empezar sin destino" : "Empezar viaje") { Task { await start() } }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity).accessibilityLabel("Empezar viaje")
            Text("El permiso de ubicación se solicita al empezar. Puedes planificar con un origen escrito sin concederlo.").font(.footnote).foregroundStyle(.secondary)
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var activeCard: some View {
        VStack(spacing: 18) {
            Text(TripFormatting.money(trip.currentCost.cents)).font(.system(size: 48, weight: .bold, design: .rounded)).minimumScaleFactor(0.5)
            Text("Combustible o energía estimada").foregroundStyle(.secondary)
            Text("\(trip.distanceMeters / 1000, specifier: "%.2f") km · \(phaseLabel)").font(.headline)
            HStack {
                if trip.phase == .interrupted {
                    Button("Continuar") { Task { await trip.resume() } }.buttonStyle(.borderedProminent)
                    Button("Terminar") { showSummary = true }.buttonStyle(.bordered)
                    Button("Descartar", role: .destructive) { Task { await trip.discardRecovered(); model.refresh() } }.buttonStyle(.bordered)
                } else if case .paused = trip.phase { Button("Reanudar") { Task { await trip.resume() } }.buttonStyle(.borderedProminent) }
                else { Button("Pausar") { Task { await trip.pause() } }.buttonStyle(.bordered) }
                if trip.phase != .interrupted { Button("Terminar") { showSummary = true }.buttonStyle(.borderedProminent).tint(.red) }
            }.controlSize(.large)
        }.padding().frame(maxWidth: .infinity).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var summarySheet: some View {
        NavigationStack {
            Form {
                Section("Finalizar") {
                    Text("Distancia registrada: \(trip.distanceMeters / 1000, specifier: "%.2f") km")
                    Text("Energía estimada: \(TripFormatting.money(trip.currentCost.cents))")
                    TextField("Peajes/parking (€)", text: $manualExpense).keyboardType(.decimalPad)
                    ShareLink(item: shareMessage) { Label("Compartir reparto", systemImage: "square.and.arrow.up") }
                }
                Section { Text("Al confirmar se recalculan los cargos en la misma transacción. Los pagos existentes no se borran.").font(.footnote) }
            }
            .navigationTitle("Resumen del viaje")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Guardar") { Task { await finish() } } }; ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showSummary = false } } }
        }
    }

    private func plan() async {
        planning = true; defer { planning = false }
        do { route = try await model.container.routing.route(.init(origin: origin, destination: destination)).first }
        catch { model.errorMessage = error.localizedDescription }
    }

    private func start() async {
        guard let vehicle = model.vehicles.first else { return }
        let participants = namedParticipants
        let group = namedMode ? selectedGroupID : SystemIDs.ungrouped
        do {
            let driving = try model.container.repository.drivingConfiguration(vehicleID: vehicle.id)
            await trip.start(.init(vehicleID: vehicle.id, vehicleName: vehicle.displayName, consumptionPer100: driving.consumptionPer100, realWorldFactor: driving.realWorldFactor, unitPrice: driving.unitPrice, people: people, splitRule: passengersOnly ? .passengersOnly : .everyone, groupID: group, participantIDs: participants.count == people ? participants : [], origin: origin, destination: destination.isEmpty ? nil : destination))
        } catch { model.errorMessage = error.localizedDescription }
    }

    private func finish() async {
        var expenses: [ExpenseInput] = []
        if !manualExpense.isEmpty, let amount = try? MoneyCents(parsing: manualExpense, locale: Locale(identifier: "es_ES")), amount.cents > 0 { expenses.append(.init(label: "Peajes/parking", kind: "other", amount: amount)) }
        let participants = namedParticipants
        await trip.finish(expenses: expenses, participantIDs: participants.count == people ? participants : [])
        showSummary = false; manualExpense = ""; model.refresh()
    }

    private var shareMessage: String {
        let expense = (try? MoneyCents(parsing: manualExpense, locale: Locale(identifier: "es_ES"))) ?? .zero
        return model.container.shareComposer.tripMessage(origin: origin, destination: destination, energyCost: trip.currentCost, expenses: expense, people: people, rule: passengersOnly ? .passengersOnly : .everyone)
    }
    private var namedParticipants: [String] {
        guard namedMode else { return [] }
        return [SystemIDs.owner] + model.people.filter { !$0.isOwner && selectedParticipantIDs.contains($0.id) }.prefix(7).map(\.id)
    }
    private var namedMode: Bool { model.isPro && useNamedParticipants }

    private var phaseLabel: String { switch trip.phase { case .starting: "Buscando señal"; case .tracking: "En marcha"; case .paused: "En pausa"; case .interrupted: "Interrumpido"; case .finishing: "Guardando"; default: "Preparando" } }
}

enum TripFormatting {
    static func money(_ cents: Int64) -> String { (Double(cents) / 100).formatted(.currency(code: "EUR").locale(Locale(identifier: "es_ES"))) }
}
