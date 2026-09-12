import SwiftUI
import UniformTypeIdentifiers

struct EuroGasDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var exporting = false
    @State private var importing = false
    @State private var document = EuroGasDataDocument()
    @State private var filename = "EuroGas-backup"
    @State private var pendingImport: Data?
    @State private var importPreview: BackupPreview?

    var body: some View {
        NavigationStack {
            List {
                Section("Acceso") { NavigationLink("EuroGas Pro") { PaywallView(model: model) }; Text(accessLabel).foregroundStyle(.secondary) }
                Section("Datos locales") {
                    Button("Exportar backup completo") { exportBackup() }
                    Button("Exportar viajes CSV") { exportTripsCSV() }
                    Button("Importar backup") { importing = true }
                    Text("El backup puede contener nombres y rutas. No incluye compras, recibos, credenciales ni muestras GPS crudas.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Ubicación") {
                    Text(locationLabel)
                    Text("La ubicación se usa durante un viaje para registrar kilómetros y estimar energía. El tracking en segundo plano debe validarse en iPhone.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Cálculo") { Text("Según los kilómetros registrados, tu consumo y el precio configurado. No incluye mantenimiento, seguro ni desgaste.") }
            }
            .navigationTitle("Ajustes")
            .fileExporter(isPresented: $exporting, document: document, contentType: filename.hasSuffix("csv") ? .commaSeparatedText : .json, defaultFilename: filename) { result in if case let .failure(error) = result { model.errorMessage = error.localizedDescription } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }; defer { url.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: url); pendingImport = data; importPreview = try model.container.backup.preview(data)
                } catch { model.errorMessage = error.localizedDescription }
            }
            .confirmationDialog("Reemplazar datos locales", isPresented: Binding(get: { importPreview != nil }, set: { if !$0 { importPreview = nil } }), titleVisibility: .visible) {
                Button("Importar y reemplazar", role: .destructive) { importBackup() }
                Button("Cancelar", role: .cancel) { pendingImport = nil; importPreview = nil }
            } message: { Text("Backup del \(importPreview?.exportedAt ?? "") con \(importPreview?.tripCount ?? 0) viajes y \(importPreview?.personCount ?? 0) personas. La validación ocurre antes de modificar la base y un error revierte la transacción.") }
        }
    }

    private var accessLabel: String { model.isPro ? "Pro activo" : "Modo Free · detalle de 30 días; datos antiguos conservados" }
    private var locationLabel: String { switch model.container.location.authorizationState { case .allowed: "Ubicación permitida"; case .reducedAccuracy: "Precisión reducida"; case .denied: "Ubicación denegada"; case .restricted: "Ubicación restringida"; case .notDetermined: "Permiso aún no solicitado" } }
    private func exportBackup() { do { document = .init(data: try model.container.backup.makeBackup()); filename = "EuroGas-backup.json"; exporting = true } catch { model.errorMessage = error.localizedDescription } }
    private func exportTripsCSV() { do { document = .init(data: Data(try model.container.backup.csvFiles().trips.utf8)); filename = "EuroGas-trips.csv"; exporting = true } catch { model.errorMessage = error.localizedDescription } }
    private func importBackup() { guard let data = pendingImport else { return }; do { try model.container.backup.importReplacingLocalData(data); pendingImport = nil; importPreview = nil; model.refresh() } catch { model.errorMessage = error.localizedDescription } }
}
