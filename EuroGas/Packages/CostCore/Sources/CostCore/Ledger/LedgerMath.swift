import Foundation

public enum LedgerMath {
    public static func balance(entries: [LedgerEntry], person: PersonID, group: GroupID) -> MoneyCents {
        MoneyCents(cents: entries.filter { $0.groupID == group && ($0.debtorID == person || $0.creditorID == person) }.reduce(Int64.zero) { total, e in
            let sign: Int64 = e.debtorID == person ? 1 : -1
            return total + (e.kind == .charge ? sign : -sign) * e.amountCents.cents
        })
    }
    public static func pending(entries: [LedgerEntry], person: PersonID, group: GroupID) -> MoneyCents { MoneyCents(cents: max(0, balance(entries: entries, person: person, group: group).cents)) }
    public static func credit(entries: [LedgerEntry], person: PersonID, group: GroupID) -> MoneyCents { MoneyCents(cents: max(0, -balance(entries: entries, person: person, group: group).cents)) }
    public static func balance(entries: [LedgerEntry], person: PersonID) -> MoneyCents { MoneyCents(cents: entries.map { balance(entries: [$0], person: person, group: $0.groupID).cents }.reduce(0, +)) }
}

