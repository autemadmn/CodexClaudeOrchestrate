struct ProGate: Equatable, Sendable {
    let state: PurchaseState

    var canCreateNamedAccountingData: Bool {
        if case .purchased = state { return true }
        return false
    }

    var canReadRetainedHistory: Bool {
        switch state {
        case .purchased, .revoked: true
        default: false
        }
    }
}
