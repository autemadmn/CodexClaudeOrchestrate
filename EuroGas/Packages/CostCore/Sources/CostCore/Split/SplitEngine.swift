import Foundation

public enum SplitRule: Equatable, Sendable { case everyone, passengersOnly }

public struct SplitResult: Equatable, Sendable {
    /// Final amounts only; their sum is already the total. An empty result means no seats are created.
    public let shares: [MoneyCents]
    public init(shares: [MoneyCents]) { self.shares = shares }
}

public enum SplitEngine {
    public static func split(total: MoneyCents, people: Int, rule: SplitRule) -> SplitResult {
        precondition(people >= 1 && people <= 8)
        precondition(rule != .passengersOnly || people > 1, "passengersOnly requiere al menos un pasajero")
        guard total.cents > 0 else { return SplitResult(shares: []) }
        switch rule {
        case .everyone:
            let q = total.cents / Int64(people), remainder = total.cents % Int64(people)
            return SplitResult(shares: [MoneyCents(cents: q + remainder)] + Array(repeating: MoneyCents(cents: q), count: people - 1))
        case .passengersOnly:
            let count = people - 1, q = total.cents / Int64(count), remainder = Int(total.cents % Int64(count))
            return SplitResult(shares: [MoneyCents.zero] + (0..<count).map { MoneyCents(cents: q + ($0 < remainder ? 1 : 0)) })
        }
    }
}
