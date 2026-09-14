import SwiftUI
import CostCore
import Persistence

struct AccountsView: View {
    @ObservedObject var model: AppModel
    @State private var selected: BalanceSummary?
    @State private var payment = ""
    @State private var statement: MonthlyStatement?

    var body: some View {
        NavigationStack {
            Group {
                if !model.isPro && model.balances.isEmpty {
                    VStack(spacing: 18) {
                        ContentUnavailableView("Cuentas es Pro", systemImage: "person.2", description: Text("Personas, grupos, pagos parciales y saldos por mes."))
                        NavigationLink("Ver Pro") { PaywallView(model: model) }.buttonStyle(.borderedProminent)
                    }
                } else if model.balances.isEmpty {
                    ContentUnavailableView("Todo al día", systemImage: "checkmark.circle", description: Text("Los cargos y pagos por grupo aparecerán aquí."))
                } else {
                    List(model.balances) { balance in
                        Button { selected = balance; statement = currentStatement(for: balance.personID) } label: {
                            HStack {
                                VStack(alignment: .leading) { Text(balance.personName); Text(balance.groupName).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(TripFormatting.money(abs(balance.balanceCents))).fontWeight(.semibold)
                                    Text(balance.balanceCents >= 0 ? "Pendiente" : "A favor").font(.caption).foregroundStyle(balance.balanceCents >= 0 ? .orange : .green)
                                }
                            }
                        }.buttonStyle(.plain).accessibilityLabel("\(balance.personName), \(balance.groupName), \(balance.balanceCents >= 0 ? "pendiente" : "a favor") \(TripFormatting.money(abs(balance.balanceCents)))")
                    }
                }
            }
            .navigationTitle("Cuentas")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { PeopleView(model: model) } label: { Image(systemName: "person.badge.plus") }.accessibilityLabel("Personas y grupos") } }
            .sheet(item: $selected) { balance in paymentSheet(balance) }
        }
    }

    private func paymentSheet(_ balance: BalanceSummary) -> some View {
        NavigationStack {
            Form {
                Section("Pago local") {
                    Text("\(balance.personName) · \(balance.groupName)")
                    TextField("Importe (€)", text: $payment).keyboardType(.decimalPad)
                    Text("Esto registra un apunte local. EuroGas no mueve dinero ni accede a bancos.").font(.footnote).foregroundStyle(.secondary)
                }
                if let statement {
                    Section("Mes actual") {
                        LabeledContent("Pendiente anterior", value: TripFormatting.money(statement.opening.cents))
                        LabeledContent("Cargos", value: TripFormatting.money(statement.charges.cents))
                        LabeledContent("Pagos", value: TripFormatting.money(statement.payments.cents))
                        LabeledContent("Cierre", value: TripFormatting.money(statement.closing.cents))
                    }
                }
                ShareLink(item: model.container.shareComposer.accountMessage(month: currentMonth, balance: balance, statement: statement)) { Label("Compartir cuenta", systemImage: "square.and.arrow.up") }
            }
            .navigationTitle("Registrar pago")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { selected = nil } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { savePayment(balance) }.disabled(!model.isPro) }
            }
        }
    }

    private func savePayment(_ balance: BalanceSummary) {
        do {
            let amount = try MoneyCents(parsing: payment, locale: Locale(identifier: "es_ES"))
            _ = try model.container.ledger.registerPayment(personID: balance.personID, amount: amount, groupID: balance.groupID, note: nil)
            payment = ""; selected = nil; model.refresh()
        } catch { model.errorMessage = error.localizedDescription }
    }

    private func currentStatement(for personID: String) -> MonthlyStatement? {
        try? model.container.ledger.monthlyStatement(personID: personID, month: currentMonth)
    }
    private var currentMonth: String { AccountingPeriod.accountingMonth(of: model.container.clock.now, in: AppEnvironment.accountingTimeZone) }
}
