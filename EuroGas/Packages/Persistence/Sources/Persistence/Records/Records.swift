import Foundation
import GRDB

public struct VehicleRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable {
    public static let databaseTableName = "Vehicle"
    public var id: String
    public var displayName: String
    public var energyKind: String
    public var activeProfileID: String?
    public var createdAt: String
    public var updatedAt: String
}

public struct ConsumptionProfileRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable {
    public static let databaseTableName = "ConsumptionProfile"
    public var id: String
    public var vehicleID: String
    public var source: String
    public var consumptionPer100: String
    public var realWorldFactor: String
    public var unit: String
    public var sourceReference: String?
    public var testCycle: String?
    public var createdAt: String
}

public struct FuelPriceRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable {
    public static let databaseTableName = "FuelPrice"
    public var id: String
    public var energyKind: String
    public var unitPriceMilliEUR: Int64
    public var currency: String
    public var source: String
    public var effectiveFrom: String
}

public struct PersonRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable, Identifiable {
    public static let databaseTableName = "Person"
    public var id: String
    public var name: String
    public var emoji: String?
    public var isOwner: Bool
    public var createdAt: String
    public var archivedAt: String?
}

public struct GroupRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable, Identifiable {
    public static let databaseTableName = "Group"
    public var id: String
    public var name: String
    public var emoji: String?
    public var isUngrouped: Bool
    public var defaultSplitRule: String
    public var createdAt: String
    public var archivedAt: String?
}

public struct GroupMemberRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable {
    public static let databaseTableName = "GroupMember"
    public var groupID: String
    public var personID: String
    public var sortOrder: Int
}

public struct TripRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable, Identifiable {
    public static let databaseTableName = "Trip"
    public var id: String
    public var vehicleID: String
    public var status: String
    public var startedAt: String
    public var endedAt: String?
    public var accountingMonth: String
    public var accountingTimeZone: String
    public var acceptedDistanceMeters: Double
    public var gapDistanceMeters: Double
    public var movingSeconds: Double
    public var pausedSeconds: Double
    public var estimatedEnergy: String
    public var energyCostCents: Int64
    public var profileConsumptionPer100: String
    public var profileRealWorldFactor: String
    public var fuelPriceMilliEUR: Int64
    public var costModelVersion: Int
    public var totalPeople: Int
    public var splitRule: String
    public var groupID: String
    public var accountingMode: String
    public var origin: String?
    public var destination: String?
    public var qualityFlags: String
    public var createdAt: String
    public var updatedAt: String
    public var revision: Int
}

public struct TripParticipantRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable {
    public static let databaseTableName = "TripParticipant"
    public var tripID: String
    public var personID: String
    public var role: String
    public var sortOrder: Int
}

public struct ManualExpenseRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable, Identifiable {
    public static let databaseTableName = "ManualExpense"
    public var id: String
    public var tripID: String
    public var label: String
    public var kind: String
    public var amountCents: Int64
    public var createdAt: String
    public var updatedAt: String
}

public struct PaymentBatchRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable, Identifiable {
    public static let databaseTableName = "PaymentBatch"
    public var id: String
    public var personID: String
    public var occurredAt: String
    public var note: String?
    public var createdAt: String
}

public struct LedgerEntryRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable, Identifiable {
    public static let databaseTableName = "LedgerEntry"
    public var id: String
    public var kind: String
    public var debtorID: String
    public var creditorID: String
    public var amountCents: Int64
    public var groupID: String
    public var tripID: String?
    public var paymentBatchID: String?
    public var occurredAt: String
    public var accountingMonth: String
    public var createdAt: String
    public var note: String?
}

public struct ActiveTripStateRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Equatable, Sendable {
    public static let databaseTableName = "ActiveTripState"
    public var tripID: String
    public var schemaVersion: Int
    public var sequence: Int
    public var savedAt: String
    public var state: String
    public var lastAcceptedFixJSON: String?
    public var accumulatorJSON: String
    public var lastMovementAt: String?
    public var unmeasuredIntervalFlag: Bool
    public var liveActivityID: String?
}
