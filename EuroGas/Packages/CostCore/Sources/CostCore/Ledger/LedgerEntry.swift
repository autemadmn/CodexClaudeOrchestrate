import Foundation

public struct LedgerEntry: Equatable, Sendable {
    public enum Kind: String, Sendable { case charge, payment }
    public let id: String
    public let kind: Kind
    public let debtorID: PersonID
    public let creditorID: PersonID
    public let amountCents: MoneyCents
    public let groupID: GroupID
    public let tripID: TripID?
    public let paymentBatchID: PaymentBatchID?
    public let occurredAt: Date
    public init(id: String, kind: Kind, debtorID: PersonID, creditorID: PersonID, amountCents: MoneyCents, groupID: GroupID, tripID: TripID? = nil, paymentBatchID: PaymentBatchID? = nil, occurredAt: Date) {
        self.id = id
        self.kind = kind
        self.debtorID = debtorID
        self.creditorID = creditorID
        self.amountCents = amountCents
        self.groupID = groupID
        self.tripID = tripID
        self.paymentBatchID = paymentBatchID
        self.occurredAt = occurredAt
    }
}
