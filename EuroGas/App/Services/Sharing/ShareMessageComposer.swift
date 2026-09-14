import Foundation
import CostCore
import Persistence

struct ShareMessageComposer: Sendable {
    func tripMessage(origin: String?, destination: String?, energyCost: MoneyCents, expenses: MoneyCents, people: Int, rule: SplitRule) -> String {
        let total = MoneyCents(cents: energyCost.cents + expenses.cents)
        let split = try? SplitEngine.split(total: total, people: people, rule: rule)
        let route = [origin, destination].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " → ")
        var lines = [route.isEmpty ? "Viaje EuroGas" : route, "Combustible o energía estimada: \(TripFormatting.money(energyCost.cents))", "Peajes/parking añadidos: \(TripFormatting.money(expenses.cents))", "Total: \(TripFormatting.money(total.cents))", "Reparto entre \(people) personas:"]
        if let shares = split?.shares, !shares.isEmpty {
            lines.append("Conductor: \(TripFormatting.money(shares[0].cents))")
            for (index, share) in shares.dropFirst().enumerated() { lines.append("Pasajero \(index + 1): \(TripFormatting.money(share.cents))") }
        }
        lines.append("Calculado con EuroGas")
        return lines.joined(separator: "\n")
    }

    func accountMessage(month: String, balance: BalanceSummary, statement: MonthlyStatement?) -> String {
        var lines = ["\(month) · \(balance.groupName)", "\(balance.personName):"]
        if let statement {
            lines += ["Pendiente anterior: \(TripFormatting.money(statement.opening.cents))", "Tu parte de los viajes del mes: \(TripFormatting.money(statement.charges.cents))", "Pagos registrados: \(TripFormatting.money(statement.payments.cents))"]
        }
        lines += [balance.balanceCents >= 0 ? "Pendiente: \(TripFormatting.money(balance.balanceCents))" : "Saldo a favor: \(TripFormatting.money(-balance.balanceCents))", "Calculado con EuroGas"]
        return lines.joined(separator: "\n")
    }
}
