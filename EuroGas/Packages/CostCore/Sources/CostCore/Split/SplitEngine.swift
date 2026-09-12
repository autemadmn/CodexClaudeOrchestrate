import Foundation

public enum SplitRule: Equatable, Sendable { case everyone, passengersOnly }

public struct SplitResult: Equatable, Sendable {
    /// Final amounts only; their sum is already the total. An empty result means no seats are created.
    public let shares: [MoneyCents]
    public init(shares: [MoneyCents]) { self.shares = shares }
}

public enum SplitEngine {
    public static func split(total: MoneyCents, people: Int, rule: SplitRule) throws -> SplitResult {
        guard people >= 1 && people <= 8 else {
            throw CostCoreError.participantCountOutOfRange(people)
        }
        guard rule != .passengersOnly || people != 1 else {
            throw CostCoreError.passengersOnlyWithoutPassengers
        }
        guard total.cents >= 0 else {
            throw CostCoreError.negativeTotal
        }
        guard total.cents > 0 else {
            return SplitResult(shares: [])
        }
        switch rule {
        case .everyone:
            let q = total.cents / Int64(people)
            let remainder = total.cents % Int64(people)
            return SplitResult(
                // Índice 0 = conductor; los índices restantes son pasajeros.
                shares: [MoneyCents(cents: q + remainder)]
                    + Array(repeating: MoneyCents(cents: q), count: people - 1)
            )
        case .passengersOnly:
            let count = people - 1
            let q = total.cents / Int64(count)
            let remainder = Int(total.cents % Int64(count))
            let shares = (0..<count).map {
                MoneyCents(cents: q + ($0 < remainder ? 1 : 0))
            }
            return SplitResult(shares: [MoneyCents.zero] + shares)
        }
    }
}
