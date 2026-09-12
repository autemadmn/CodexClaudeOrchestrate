import SwiftUI

@main
struct EuroGasApp: App {
    private let container: AppContainer
    private let startupError: String?

    init() {
        do { container = try AppContainer.live(); startupError = nil }
        catch { container = AppContainer.preview(); startupError = "No se pudo abrir la base local: \(error.localizedDescription)" }
    }

    var body: some Scene {
        WindowGroup { RootView(container: container, startupError: startupError) }
    }
}
