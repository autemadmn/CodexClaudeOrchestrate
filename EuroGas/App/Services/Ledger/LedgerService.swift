import Foundation
import CostCore
import Persistence

protocol LedgerService: Sendable {
    func balances() throws -> [BalanceSummary]
    func monthlyStatement(personID: String, month: String) throws -> MonthlyStatement
    func proposePayment(personID: String, amount: MoneyCents, creditGroupID: String?) throws -> [(groupID: GroupID, amount: MoneyCents)]
    func registerPayment(personID: String, amount: MoneyCents, groupID: String, note: String?) throws -> String
    func undo(batchID: String) throws
}

final class LocalLedgerService: LedgerService, @unchecked Sendable {
    private let repository: AppRepository
    private let clock: any AppClock
    init(repository: AppRepository, clock: any AppClock) { self.repository = repository; self.clock = clock }
    func balances() throws -> [BalanceSummary] { try repository.balances() }
    func monthlyStatement(personID: String, month: String) throws -> MonthlyStatement { try repository.monthlyStatement(personID: personID, month: month) }
    func proposePayment(personID: String, amount: MoneyCents, creditGroupID: String?) throws -> [(groupID: GroupID, amount: MoneyCents)] {
        let groups = try repository.groups(includeArchived: true)
        let byID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        let pending = try repository.balances().filter { $0.personID == personID && $0.balanceCents > 0 }.compactMap { balance -> GroupPending? in
            guard let group = byID[balance.groupID], let date = ISO8601DateFormatter().date(from: group.createdAt) else { return nil }
            return GroupPending(groupID: GroupID(group.id), pending: MoneyCents(cents: balance.balanceCents), createdAt: date, id: group.id)
        }
        return try PaymentAllocationProposal.propose(amount: amount, pendingByGroup: pending, creditGroupID: creditGroupID.map(GroupID.init))
    }
    func registerPayment(personID: String, amount: MoneyCents, groupID: String, note: String?) throws -> String { try repository.recordPayment(personID: personID, allocations: [(groupID, amount)], occurredAt: clock.now, note: note) }
    func undo(batchID: String) throws { try repository.undoPayment(batchID: batchID) }
}
