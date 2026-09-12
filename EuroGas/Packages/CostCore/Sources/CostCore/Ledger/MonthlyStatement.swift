import Foundation
public struct MonthlyStatement: Equatable, Sendable {
    public let opening: MoneyCents
    public let charges: MoneyCents
    public let payments: MoneyCents
    public let closing: MoneyCents

    public init(opening: MoneyCents, charges: MoneyCents, payments: MoneyCents) {
        self.opening = opening
        self.charges = charges
        self.payments = payments
        self.closing = MoneyCents(cents: opening.cents + charges.cents - payments.cents)
    }

    public init(entries: [LedgerEntry], person: PersonID, forMonth month: String, in timeZone: TimeZone) throws {
        let period = try AccountingPeriod.bounds(forMonth: month, in: timeZone)
        let relevant = entries.filter { $0.debtorID == person || $0.creditorID == person }
        let before = relevant.filter { $0.occurredAt < period.start }
        let inMonth = relevant.filter { $0.occurredAt >= period.start && $0.occurredAt < period.end }
        func signed(_ entry: LedgerEntry) -> Int64 {
            let direction: Int64 = entry.debtorID == person ? 1 : -1
            return (entry.kind == .charge ? direction : -direction) * entry.amountCents.cents
        }
        opening = MoneyCents(cents: before.reduce(0) { $0 + signed($1) })
        charges = MoneyCents(cents: inMonth.filter { $0.kind == .charge }.reduce(0) { $0 + signed($1) })
        payments = MoneyCents(cents: inMonth.filter { $0.kind == .payment }.reduce(0) { $0 - signed($1) })
        closing = MoneyCents(cents: opening.cents + charges.cents - payments.cents)
    }

    public static func build(entries: [LedgerEntry], person: PersonID, forMonth month: String, in timeZone: TimeZone) throws -> Self {
        try Self(entries: entries, person: person, forMonth: month, in: timeZone)
    }
}
