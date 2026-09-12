import Foundation
public struct GroupPending: Equatable, Sendable { public let groupID: GroupID; public let pending: MoneyCents; public let createdAt: Date; public let id: String; public init(groupID: GroupID, pending: MoneyCents, createdAt: Date, id: String) { self.groupID=groupID; self.pending=pending; self.createdAt=createdAt; self.id=id } }
public enum PaymentAllocationError: Error, Equatable { case nonPositiveAmount, missingCreditGroup, invalidCreditGroup }
public enum PaymentAllocationProposal {
    public static func propose(amount: MoneyCents, pendingByGroup: [GroupPending]) throws -> [(groupID: GroupID, amount: MoneyCents)] { try propose(amount: amount, pendingByGroup: pendingByGroup, creditGroupID: nil) }
    public static func propose(amount: MoneyCents, pendingByGroup: [GroupPending], creditGroupID: GroupID?) throws -> [(groupID: GroupID, amount: MoneyCents)] {
        guard amount.cents > 0 else { throw PaymentAllocationError.nonPositiveAmount }; let groups=pendingByGroup.filter{$0.pending.cents>0}.sorted{ $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt }; var left=amount.cents; var out:[(groupID:GroupID,amount:MoneyCents)]=[]
        for g in groups where left > 0 { let n=min(left,g.pending.cents); out.append((g.groupID,MoneyCents(cents:n))); left -= n }
        if left > 0 { guard let id=creditGroupID else { throw PaymentAllocationError.missingCreditGroup }; out.append((id,MoneyCents(cents:left))) }
        guard !out.isEmpty else { guard creditGroupID != nil else { throw PaymentAllocationError.missingCreditGroup }; out.append((creditGroupID!, amount)) }; return out
    }
}
