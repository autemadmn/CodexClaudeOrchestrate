import StoreKit

@MainActor
final class StoreKitPurchaseAccess: ObservableObject, PurchaseAccess {
    @Published private(set) var state: PurchaseState = .unknown
    @Published private(set) var displayPrice: String?
    private var product: Product?
    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case let .verified(transaction) = result {
                    await self.apply(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    deinit { updateTask?.cancel() }

    func refresh() async {
        do {
            product = try await Product.products(for: [AppEnvironment.provisionalProProductID]).first
            displayPrice = product?.displayPrice
            var found = false
            for await result in Transaction.currentEntitlements {
                guard case let .verified(transaction) = result, transaction.productID == AppEnvironment.provisionalProProductID else { continue }
                found = true
                await apply(transaction)
            }
            if !found { state = .free }
        } catch { state = .unavailable("La tienda no está disponible. Puedes seguir usando el modo Free.") }
    }

    func purchase() async {
        guard let product else { await refresh(); return }
        state = .purchasing
        do {
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                await apply(transaction); await transaction.finish()
            case .pending: state = .pending
            case .userCancelled: state = .free
            default: state = .unavailable("No se pudo verificar la compra.")
            }
        } catch { state = .unavailable("La compra no se completó. Tus datos no han cambiado.") }
    }

    func restore() async {
        do { try await AppStore.sync(); await refresh() }
        catch { state = .unavailable("No se pudieron restaurar las compras ahora.") }
    }

    private func apply(_ transaction: Transaction) async {
        guard transaction.productID == AppEnvironment.provisionalProProductID else { return }
        state = transaction.revocationDate == nil ? .purchased : .revoked
    }
}
