import SwiftUI

@main
struct EuroGasApp: App {
    private let container: AppContainer?
    private let startupError: String?

    init() {
        do { container = try AppContainer.live(); startupError = nil }
        catch { container = nil; startupError = "No se pudo abrir la base local: \(error.localizedDescription)" }
    }

    var body: some Scene {
        WindowGroup {
            if let container { RootView(container: container) }
            else { ContentUnavailableView("EuroGas no puede abrir sus datos", systemImage: "externaldrive.badge.exclamationmark", description: Text(startupError ?? "Error desconocido")) }
        }
    }
}
