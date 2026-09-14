import SwiftUI
import CostCore
import Persistence

struct TripsView: View {
    @ObservedObject var model: AppModel
    @State private var pendingDelete: String?

    var body: some View {
        NavigationStack {
            Group {
                if model.visibleTrips.isEmpty { ContentUnavailableView("No hay viajes visibles", systemImage: "car", description: Text(model.trips.isEmpty ? "Los viajes finalizados aparecerán aquí." : "El modo Free muestra el detalle de los últimos 30 días.")) }
                else {
                    List(model.visibleTrips) { trip in
                        NavigationLink { TripEditView(model: model, trip: trip) } label: {
                            VStack(alignment: .leading) {
                                Text(trip.destination ?? "Viaje libre").font(.headline)
                                Text("\(trip.startedAt) · \(trip.acceptedDistanceMeters / 1000, specifier: "%.1f") km · \(TripFormatting.money(trip.energyCostCents))").foregroundStyle(.secondary)
                            }.accessibilityElement(children: .combine)
                        }
                        .swipeActions { Button("Borrar", role: .destructive) { pendingDelete = trip.id } }
                    }
                }
            }
            .navigationTitle("Viajes")
            .refreshable { model.refresh() }
            .confirmationDialog("¿Borrar este viaje?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Borrar viaje y sus cargos", role: .destructive) {
                    guard let id = pendingDelete else { return }
                    do { try model.container.repository.deleteTrip(id: id); model.refresh() } catch { model.errorMessage = error.localizedDescription }
                    pendingDelete = nil
                }
                Button("Cancelar", role: .cancel) { pendingDelete = nil }
            } message: { Text("Se eliminarán los cargos derivados del viaje. Los pagos registrados se conservarán.") }
        }
    }
}

private struct TripEditView: View {
    @ObservedObject var model: AppModel
    let trip: TripRecord
    @State private var expenseText = ""
    @State private var participants: [String] = []
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Viaje") {
                LabeledContent("Destino", value: trip.destination ?? "Viaje libre")
                LabeledContent("Distancia", value: "\(trip.acceptedDistanceMeters / 1000, specifier: "%.1f") km")
                LabeledContent("Energía", value: TripFormatting.money(trip.energyCostCents))
            }
            Section("Gasto manual") {
                TextField("Importe total de peajes/parking (€)", text: $expenseText).keyboardType(.decimalPad)
                Text("Guardar reemplaza los cargos derivados del viaje en una transacción. Los pagos permanecen.").font(.footnote).foregroundStyle(.secondary)
            }
            Section { Button("Guardar cambios") { save() }.disabled(!loaded || (trip.accountingMode == "named" && !model.isPro)) }
        }
        .navigationTitle("Editar viaje")
        .task { load() }
    }

    private func load() {
        do {
            participants = try model.container.repository.participantIDs(tripID: trip.id)
            let cents = try model.container.repository.expenses(tripID: trip.id).reduce(Int64.zero) { $0 + $1.amountCents }
            expenseText = cents == 0 ? "" : String(format: "%.2f", Double(cents) / 100).replacingOccurrences(of: ".", with: ",")
            loaded = true
        } catch { model.errorMessage = error.localizedDescription }
    }

    private func save() {
        do {
            let amount = expenseText.isEmpty ? MoneyCents.zero : try MoneyCents(parsing: expenseText, locale: Locale(identifier: "es_ES"))
            let expenses = amount.cents > 0 ? [ExpenseInput(label: "Peajes/parking", kind: "other", amount: amount)] : []
            guard let ended = trip.endedAt.flatMap({ ISO8601DateFormatter().date(from: $0) }) else { throw PersistenceError.invalidState("El viaje no tiene fecha final válida.") }
            try model.container.repository.editCompletedTrip(.init(tripID: trip.id, endedAt: ended, expenses: expenses, participantIDs: participants))
            model.refresh()
        } catch { model.errorMessage = error.localizedDescription }
    }
}
