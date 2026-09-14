import SwiftUI

struct PaywallView: View {
    @ObservedObject var model: AppModel
    @State private var status = ""
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.badge.gearshape").font(.system(size: 56)).foregroundStyle(.tint)
            Text("EuroGas Pro").font(.largeTitle.bold())
            Text("Lleva las cuentas con tus compañeros de coche. Personas, grupos y saldos mes a mes. Compra única.").multilineTextAlignment(.center)
            Text("Los viajes y pagos existentes nunca se borran si la compra se revoca.").font(.footnote).foregroundStyle(.secondary)
            Button("Comprar \(model.purchaseDisplayPrice ?? "")") { Task { await model.purchase(); status = purchaseLabel; model.refresh() } }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(model.purchaseDisplayPrice == nil)
            Button("Restaurar compras") { Task { await model.restorePurchases(); status = purchaseLabel; model.refresh() } }
            if !status.isEmpty { Text(status).foregroundStyle(.secondary) }
        }.padding().navigationTitle("Pro")
    }
    private var purchaseLabel: String { switch model.purchaseState { case .purchased: "Pro activo"; case .pending: "Compra pendiente"; case .revoked: "Compra revocada; datos conservados"; case let .unavailable(message): message; default: "Modo Free" } }
}
