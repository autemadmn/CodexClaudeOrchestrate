import Foundation
import CostCore

public struct VehicleSetup: Equatable, Sendable {
    public let displayName: String
    public let energyKind: String
    public let consumptionPer100: Decimal
    public let unitPrice: UnitPriceMilliEUR
    public init(displayName: String, energyKind: String, consumptionPer100: Decimal, unitPrice: UnitPriceMilliEUR) {
        self.displayName = displayName
        self.energyKind = energyKind
        self.consumptionPer100 = consumptionPer100
        self.unitPrice = unitPrice
    }
}

public struct TripStartRequest: Equatable, Sendable {
    public let vehicleID: String
    public let consumptionPer100: Decimal
    public let realWorldFactor: Decimal
    public let unitPrice: UnitPriceMilliEUR
    public let totalPeople: Int
    public let splitRule: SplitRule
    public let groupID: String
    public let participantIDs: [String]
    public let origin: String?
    public let destination: String?
    public let startedAt: Date
    public init(vehicleID: String, consumptionPer100: Decimal, realWorldFactor: Decimal = 1, unitPrice: UnitPriceMilliEUR, totalPeople: Int, splitRule: SplitRule, groupID: String = SystemIDs.ungrouped, participantIDs: [String] = [], origin: String? = nil, destination: String? = nil, startedAt: Date) {
        self.vehicleID = vehicleID
        self.consumptionPer100 = consumptionPer100
        self.realWorldFactor = realWorldFactor
        self.unitPrice = unitPrice
        self.totalPeople = totalPeople
        self.splitRule = splitRule
        self.groupID = groupID
        self.participantIDs = participantIDs
        self.origin = origin
        self.destination = destination
        self.startedAt = startedAt
    }
}

public struct TripCheckpoint: Equatable, Sendable {
    public let tripID: String
    public let state: ActiveTripState
    public let energyCost: MoneyCents
    public let estimatedEnergy: Decimal
    public let movingSeconds: TimeInterval
    public let pausedSeconds: TimeInterval
    public init(tripID: String, state: ActiveTripState, energyCost: MoneyCents, estimatedEnergy: Decimal, movingSeconds: TimeInterval, pausedSeconds: TimeInterval) {
        self.tripID = tripID
        self.state = state
        self.energyCost = energyCost
        self.estimatedEnergy = estimatedEnergy
        self.movingSeconds = movingSeconds
        self.pausedSeconds = pausedSeconds
    }
}

public struct ExpenseInput: Codable, Equatable, Sendable {
    public let label: String
    public let kind: String
    public let amount: MoneyCents
    public init(label: String, kind: String, amount: MoneyCents) { self.label = label; self.kind = kind; self.amount = amount }
}

public struct TripCompletion: Equatable, Sendable {
    public let tripID: String
    public let endedAt: Date
    public let expenses: [ExpenseInput]
    public let participantIDs: [String]
    public init(tripID: String, endedAt: Date, expenses: [ExpenseInput], participantIDs: [String]) {
        self.tripID = tripID; self.endedAt = endedAt; self.expenses = expenses; self.participantIDs = participantIDs
    }
}

public struct BalanceSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String { personID + "|" + groupID }
    public let personID: String
    public let personName: String
    public let groupID: String
    public let groupName: String
    public let balanceCents: Int64
}

public struct BackupDocument: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let exportedAt: String
    public let accountingTimeZone: String
    public let vehicles: [VehicleRecord]
    public let consumptionProfiles: [ConsumptionProfileRecord]
    public let fuelPrices: [FuelPriceRecord]
    public let people: [PersonRecord]
    public let groups: [GroupRecord]
    public let groupMembers: [GroupMemberRecord]
    public let trips: [TripRecord]
    public let tripParticipants: [TripParticipantRecord]
    public let manualExpenses: [ManualExpenseRecord]
    public let paymentBatches: [PaymentBatchRecord]
    public let payments: [LedgerEntryRecord]
}

public struct CSVExport: Equatable, Sendable {
    public let trips: String
    public let accounts: String
    public init(trips: String, accounts: String) { self.trips = trips; self.accounts = accounts }
}
