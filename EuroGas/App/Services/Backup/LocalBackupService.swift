import Foundation
import Persistence

protocol BackupService: Sendable {
    func makeBackup() throws -> Data
    func preview(_ data: Data) throws -> BackupPreview
    func importReplacingLocalData(_ data: Data) throws
    func csvFiles() throws -> CSVExport
}

struct BackupPreview: Equatable, Sendable {
    let exportedAt: String
    let tripCount: Int
    let personCount: Int
}

final class LocalBackupService: BackupService, @unchecked Sendable {
    private let repository: AppRepository
    private let clock: any AppClock
    init(repository: AppRepository, clock: any AppClock) { self.repository = repository; self.clock = clock }
    func makeBackup() throws -> Data { try repository.exportBackup(now: clock.now) }
    func preview(_ data: Data) throws -> BackupPreview {
        let backup = try JSONDecoder().decode(BackupDocument.self, from: data)
        guard backup.schemaVersion == 1 else { throw PersistenceError.invalidBackup("Versión de backup no compatible.") }
        return .init(exportedAt: backup.exportedAt, tripCount: backup.trips.count, personCount: backup.people.count)
    }
    func importReplacingLocalData(_ data: Data) throws { try repository.importBackup(data) }
    func csvFiles() throws -> CSVExport { try repository.exportCSV() }
}
