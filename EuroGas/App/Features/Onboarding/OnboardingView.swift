import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var step = 0
    @State private var name = "Mi coche"
    @State private var energy = "gasoline"
    @State private var consumption = "6,0"
    @State private var price = "1,499"

    var body: some View {
        NavigationStack {
            Form {
                if step == 0 {
                    Section("Calcula y comparte") {
                        Label("Registra kilómetros y estima combustible o energía.", systemImage: "fuelpump.fill")
                        Text("La cifra es una estimación basada en tu consumo y precio configurados; no incluye mantenimiento ni desgaste.").foregroundStyle(.secondary)
                    }
                } else if step == 1 {
                    Section("Tu vehículo") {
                        TextField("Nombre del coche", text: $name).accessibilityLabel("Nombre del vehículo")
                        Picker("Energía", selection: $energy) {
                            Text("Gasolina").tag("gasoline"); Text("Diésel").tag("diesel"); Text("GLP").tag("lpg"); Text("Híbrido").tag("hev"); Text("Eléctrico").tag("bev")
                        }
                        TextField(energy == "bev" ? "kWh/100 km" : "L/100 km", text: $consumption).keyboardType(.decimalPad)
                    }
                } else {
                    Section("Precio") {
                        TextField(energy == "bev" ? "€/kWh" : "€/L", text: $price).keyboardType(.decimalPad)
                        Text("Puedes cambiarlo más tarde. Se guarda en milésimas de euro para no confundirlo con el coste final.").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Bienvenido a EuroGas")
            .safeAreaInset(edge: .bottom) {
                Button(step == 2 ? "Guardar y continuar" : "Siguiente") {
                    if step < 2 { step += 1 } else { _ = model.configureVehicle(name: name, energy: energy, consumption: consumption, price: price) }
                }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity).padding().background(.bar)
                .accessibilityHint(step == 2 ? "Guarda el vehículo" : "Avanza al siguiente paso")
            }
        }
    }
}
