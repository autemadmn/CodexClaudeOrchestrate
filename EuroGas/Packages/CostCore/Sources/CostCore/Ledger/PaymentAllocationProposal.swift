import Foundation
public struct GroupPending: Equatable, Sendable {
    public let groupID: GroupID
    public let pending: MoneyCents
    public let createdAt: Date
    public let id: String
    public init(groupID: GroupID, pending: MoneyCents, createdAt: Date, id: String) {
        self.groupID = groupID
        self.pending = pending
        self.createdAt = createdAt
        self.id = id
    }
}
public enum PaymentAllocationError: Error, Equatable { case nonPositiveAmount, missingCreditGroup, invalidCreditGroup }
public enum PaymentAllocationProposal {
    public static func propose(amount: MoneyCents, pendingByGroup: [GroupPending]) throws -> [(groupID: GroupID, amount: MoneyCents)] {
        try propose(amount: amount, pendingByGroup: pendingByGroup, creditGroupID: nil)
    }
    public static func propose(amount: MoneyCents, pendingByGroup: [GroupPending], creditGroupID: GroupID?) throws -> [(groupID: GroupID, amount: MoneyCents)] {
        guard amount.cents > 0 else { throw PaymentAllocationError.nonPositiveAmount }
        let groups = pendingByGroup.filter { $0.pending.cents > 0 }.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
        var left = amount.cents
        var out: [(groupID: GroupID, amount: MoneyCents)] = []
        for group in groups where left > 0 {
            let allocation = min(left, group.pending.cents)
            out.append((group.groupID, MoneyCents(cents: allocation)))
            left -= allocation
        }
        if left > 0 {
            guard let id = creditGroupID else { throw PaymentAllocationError.missingCreditGroup }
            out.append((id, MoneyCents(cents: left)))
        }
        guard !out.isEmpty else {
            guard let id = creditGroupID else { throw PaymentAllocationError.missingCreditGroup }
            out.append((id, amount))
        }
        return out
    }
}
