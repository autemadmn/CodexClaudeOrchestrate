import SwiftUI

struct TripsView: View {
    @ObservedObject var model: AppModel
    @State private var pendingDelete: String?

    var body: some View {
        NavigationStack {
            Group {
                if model.trips.isEmpty { ContentUnavailableView("Aún no hay viajes", systemImage: "car", description: Text("Los viajes finalizados aparecerán aquí.")) }
                else {
                    List(model.trips) { trip in
                        VStack(alignment: .leading) {
                            Text(trip.destination ?? "Viaje libre").font(.headline)
                            Text("\(trip.startedAt) · \(trip.acceptedDistanceMeters / 1000, specifier: "%.1f") km · \(TripFormatting.money(trip.energyCostCents))").foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
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
