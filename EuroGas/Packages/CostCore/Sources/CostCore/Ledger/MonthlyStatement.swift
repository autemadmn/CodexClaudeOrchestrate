import Foundation
public struct MonthlyStatement: Equatable, Sendable {
    public let opening: MoneyCents; public let charges: MoneyCents; public let payments: MoneyCents; public let closing: MoneyCents
    public init(opening: MoneyCents, charges: MoneyCents, payments: MoneyCents) { self.opening=opening; self.charges=charges; self.payments=payments; self.closing=MoneyCents(cents: opening.cents + charges.cents - payments.cents) }
}

