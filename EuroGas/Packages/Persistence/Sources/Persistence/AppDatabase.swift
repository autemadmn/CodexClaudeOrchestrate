import Foundation
import GRDB

public enum PersistenceError: Error, Equatable, LocalizedError {
    case missingCanonicalDDL
    case noOwner
    case noUngroupedGroup
    case activeTripExists
    case activeTripMissing
    case invalidState(String)
    case invalidBackup(String)

    public var errorDescription: String? {
        switch self {
        case .missingCanonicalDDL: return "No se encuentra la migración SQL canónica v1."
        case .noOwner: return "La base no contiene el propietario local."
        case .noUngroupedGroup: return "La base no contiene el grupo técnico Sin grupo."
        case .activeTripExists: return "Ya hay un viaje activo o interrumpido."
        case .activeTripMissing: return "No hay un viaje activo que se pueda actualizar."
        case let .invalidState(message): return message
        case let .invalidBackup(message): return message
        }
    }
}

public final class AppDatabase: @unchecked Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.makeMigrator().migrate(writer)
        try bootstrapRequiredRows()
    }

    public static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var configuration = Configuration()
        configuration.label = "EuroGas"
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        return try AppDatabase(writer: DatabasePool(path: url.path, configuration: configuration))
    }

    public static func inMemory() throws -> AppDatabase {
        var configuration = Configuration()
        configuration.label = "EuroGasTests"
        configuration.prepareDatabase { db in try db.execute(sql: "PRAGMA foreign_keys = ON") }
        return try AppDatabase(writer: DatabaseQueue(configuration: configuration))
    }

    public static func readOnly(at url: URL) throws -> any DatabaseReader {
        var configuration = Configuration()
        configuration.readonly = true
        configuration.prepareDatabase { db in try db.execute(sql: "PRAGMA foreign_keys = ON") }
        return try DatabaseQueue(path: url.path, configuration: configuration)
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-canonical-sql") { db in
            guard let url = Bundle.module.url(forResource: "v1_initial", withExtension: "sql") else {
                throw PersistenceError.missingCanonicalDDL
            }
            let sql = try String(contentsOf: url, encoding: .utf8)
            try db.execute(sql: sql)
        }
        return migrator
    }

    private func bootstrapRequiredRows() throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try writer.write { db in
            if try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Person WHERE isOwner = 1") == 0 {
                try db.execute(sql: "INSERT INTO Person (id,name,isOwner,createdAt) VALUES (?,?,1,?)", arguments: [SystemIDs.owner, "Yo", now])
            }
            if try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \"Group\" WHERE isUngrouped = 1") == 0 {
                try db.execute(sql: "INSERT INTO \"Group\" (id,name,isUngrouped,createdAt) VALUES (?,?,1,?)", arguments: [SystemIDs.ungrouped, "Sin grupo", now])
            }
        }
    }
}

public enum SystemIDs {
    public static let owner = "00000000-0000-4000-8000-000000000001"
    public static let ungrouped = "00000000-0000-4000-8000-000000000002"
}
