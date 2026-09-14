import Foundation
import GRDB
import CostCore

public final class EuroGasStore: @unchecked Sendable {
    public let database: AppDatabase
    private let iso = ISO8601DateFormatter()
    private let accountingTimeZone = TimeZone(identifier: "Europe/Madrid")!

    public init(database: AppDatabase) { self.database = database }

    @discardableResult
    public func configureVehicle(_ setup: VehicleSetup, now: Date = Date()) throws -> String {
        guard setup.consumptionPer100 > 0, setup.unitPrice.milliEUR > 0 else { throw PersistenceError.invalidState("Consumo y precio deben ser positivos.") }
        let vehicleID = UUID().uuidString
        let profileID = UUID().uuidString
        let priceID = UUID().uuidString
        let date = iso.string(from: now)
        let unit = setup.energyKind == "bev" ? "kWhPer100KM" : "litresPer100KM"
        try database.writer.write { db in
            try db.execute(sql: "INSERT INTO Vehicle (id,displayName,energyKind,activeProfileID,createdAt,updatedAt) VALUES (?,?,?,?,?,?)", arguments: [vehicleID, setup.displayName, setup.energyKind, profileID, date, date])
            try db.execute(sql: "INSERT INTO ConsumptionProfile (id,vehicleID,source,consumptionPer100,realWorldFactor,unit,createdAt) VALUES (?,?,?,?,?,?,?)", arguments: [profileID, vehicleID, "userEntered", Self.decimal(setup.consumptionPer100), "1", unit, date])
            try db.execute(sql: "INSERT INTO FuelPrice (id,energyKind,unitPriceMilliEUR,currency,source,effectiveFrom) VALUES (?,?,?,?,?,?)", arguments: [priceID, setup.energyKind, setup.unitPrice.milliEUR, "EUR", "manual", date])
        }
        return vehicleID
    }

    public func vehicles() throws -> [VehicleRecord] { try database.writer.read { try VehicleRecord.order(Column("createdAt")).fetchAll($0) } }
    public func drivingConfiguration(vehicleID: String) throws -> DrivingConfiguration {
        try database.writer.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT cp.consumptionPer100, cp.realWorldFactor, fp.unitPriceMilliEUR
                FROM Vehicle v JOIN ConsumptionProfile cp ON cp.id=v.activeProfileID
                JOIN FuelPrice fp ON fp.energyKind=v.energyKind
                WHERE v.id=? ORDER BY fp.effectiveFrom DESC LIMIT 1
                """, arguments: [vehicleID]),
                  let consumption = Decimal(string: row["consumptionPer100"] as String),
                  let factor = Decimal(string: row["realWorldFactor"] as String) else { throw PersistenceError.invalidState("Falta la configuración de consumo o precio del vehículo.") }
            return DrivingConfiguration(consumptionPer100: consumption, realWorldFactor: factor, unitPrice: UnitPriceMilliEUR(milliEUR: row["unitPriceMilliEUR"]))
        }
    }
    public func people(includeArchived: Bool = false) throws -> [PersonRecord] { try database.writer.read { db in try PersonRecord.filter(includeArchived ? SQLLiteral(sql: "1") : SQLLiteral(sql: "archivedAt IS NULL")).order(Column("isOwner").desc, Column("createdAt")).fetchAll(db) } }
    public func groups(includeArchived: Bool = false) throws -> [GroupRecord] { try database.writer.read { db in try GroupRecord.filter(includeArchived ? SQLLiteral(sql: "1") : SQLLiteral(sql: "archivedAt IS NULL")).order(Column("isUngrouped").desc, Column("createdAt")).fetchAll(db) } }
    public func completedTrips() throws -> [TripRecord] { try database.writer.read { try TripRecord.filter(Column("status") == "completed").order(Column("startedAt").desc).fetchAll($0) } }
    public func activeTrip() throws -> TripRecord? { try database.writer.read { try TripRecord.filter(Column("status") == "active" || Column("status") == "interrupted").fetchOne($0) } }
    public func participantIDs(tripID: String) throws -> [String] { try database.writer.read { db in try TripParticipantRecord.filter(Column("tripID") == tripID).order(Column("sortOrder")).fetchAll(db).map(\.personID) } }
    public func expenses(tripID: String) throws -> [ManualExpenseRecord] { try database.writer.read { db in try ManualExpenseRecord.filter(Column("tripID") == tripID).order(Column("createdAt")).fetchAll(db) } }

    @discardableResult
    public func createPerson(name: String, emoji: String? = nil, now: Date = Date()) throws -> String {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PersistenceError.invalidState("El nombre no puede estar vacío.") }
        let id = UUID().uuidString
        try database.writer.write { db in try db.execute(sql: "INSERT INTO Person (id,name,emoji,isOwner,createdAt) VALUES (?,?,?,0,?)", arguments: [id, name, emoji, iso.string(from: now)]) }
        return id
    }

    @discardableResult
    public func createGroup(name: String, memberIDs: [String], now: Date = Date()) throws -> String {
        let id = UUID().uuidString
        let createdAt = iso.string(from: now)
        try database.writer.write { db in
            try db.execute(sql: "INSERT INTO \"Group\" (id,name,isUngrouped,createdAt) VALUES (?,?,0,?)", arguments: [id, name, createdAt])
            for (index, personID) in memberIDs.enumerated() {
                try db.execute(sql: "INSERT INTO GroupMember (groupID,personID,sortOrder) VALUES (?,?,?)", arguments: [id, personID, index])
            }
        }
        return id
    }

    @discardableResult
    public func startTrip(_ request: TripStartRequest) throws -> String {
        guard request.totalPeople >= 1 && request.totalPeople <= 8 else { throw CostCoreError.participantCountOutOfRange(request.totalPeople) }
        if request.splitRule == .passengersOnly, request.totalPeople == 1 { throw CostCoreError.passengersOnlyWithoutPassengers }
        let named = !request.participantIDs.isEmpty
        if named {
            guard request.participantIDs.count == request.totalPeople, request.participantIDs.first == SystemIDs.owner else { throw PersistenceError.invalidState("Los participantes named deben incluir al propietario en la posición 0.") }
        }
        let id = UUID().uuidString
        let date = iso.string(from: request.startedAt)
        let month = AccountingPeriod.accountingMonth(of: request.startedAt, in: accountingTimeZone)
        let rule = request.splitRule == .everyone ? "everyone" : "passengersOnly"
        let accumulator = try Self.json(GPSAccumulatorSnapshot())
        try database.writer.write { db in
            guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Trip WHERE status IN ('active','interrupted')") == 0 else { throw PersistenceError.activeTripExists }
            try db.execute(sql: "INSERT INTO Trip (id,vehicleID,status,startedAt,accountingMonth,profileConsumptionPer100,profileRealWorldFactor,fuelPriceMilliEUR,costModelVersion,totalPeople,splitRule,groupID,accountingMode,origin,destination,createdAt,updatedAt) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", arguments: [id, request.vehicleID, "active", date, month, Self.decimal(request.consumptionPer100), Self.decimal(request.realWorldFactor), request.unitPrice.milliEUR, costModelVersion, request.totalPeople, rule, request.groupID, named ? "named" : "anonymous", request.origin, request.destination, date, date])
            for (index, personID) in request.participantIDs.enumerated() {
                try db.execute(sql: "INSERT INTO TripParticipant (tripID,personID,role,sortOrder) VALUES (?,?,?,?)", arguments: [id, personID, index == 0 ? "driver" : "passenger", index])
            }
            try db.execute(sql: "INSERT INTO ActiveTripState (tripID,sequence,savedAt,state,accumulatorJSON) VALUES (?,0,?,'starting',?)", arguments: [id, date, accumulator])
        }
        return id
    }

    public func checkpoint(_ checkpoint: TripCheckpoint) throws {
        let state = Self.phaseString(checkpoint.state.phase)
        guard ["starting", "tracking", "paused", "interrupted", "finishing"].contains(state) else { throw PersistenceError.invalidState("El checkpoint no admite este estado.") }
        try database.writer.write { db in
            guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Trip WHERE id = ? AND status IN ('active','interrupted')", arguments: [checkpoint.tripID]) == 1 else { throw PersistenceError.activeTripMissing }
            try db.execute(sql: "UPDATE Trip SET status=?,acceptedDistanceMeters=?,gapDistanceMeters=?,movingSeconds=?,pausedSeconds=?,estimatedEnergy=?,energyCostCents=?,updatedAt=?,revision=revision+1 WHERE id=?", arguments: [state == "interrupted" ? "interrupted" : "active", checkpoint.state.accumulator.acceptedDistanceMeters, checkpoint.state.accumulator.estimatedGapDistanceMeters, checkpoint.movingSeconds, checkpoint.pausedSeconds, Self.decimal(checkpoint.estimatedEnergy), checkpoint.energyCost.cents, iso.string(from: checkpoint.state.savedAt), checkpoint.tripID])
            try db.execute(sql: "UPDATE ActiveTripState SET schemaVersion=?,sequence=?,savedAt=?,state=?,lastAcceptedFixJSON=?,accumulatorJSON=?,lastMovementAt=?,unmeasuredIntervalFlag=?,liveActivityID=? WHERE tripID=?", arguments: [checkpoint.state.schemaVersion, checkpoint.state.sequence, iso.string(from: checkpoint.state.savedAt), state, try checkpoint.state.lastAcceptedFix.map(Self.json), try Self.json(checkpoint.state.accumulator), checkpoint.state.lastMovementAt.map(iso.string), checkpoint.state.unmeasuredIntervalFlag, checkpoint.state.liveActivityID, checkpoint.tripID])
        }
    }

    public func activeTripState() throws -> ActiveTripState? {
        try database.writer.read { db in
            guard let record = try ActiveTripStateRecord.fetchOne(db) else { return nil }
            guard let phase = Self.phase(record.state) else { throw PersistenceError.invalidState("Estado activo desconocido: \(record.state)") }
            return ActiveTripState(tripID: TripID(record.tripID), schemaVersion: record.schemaVersion, sequence: record.sequence, savedAt: try Self.date(record.savedAt), phase: phase, lastAcceptedFix: try record.lastAcceptedFixJSON.map(Self.decode), accumulator: try Self.decode(record.accumulatorJSON), lastMovementAt: try record.lastMovementAt.map(Self.date), unmeasuredIntervalFlag: record.unmeasuredIntervalFlag, liveActivityID: record.liveActivityID)
        }
    }

    public func completeTrip(_ completion: TripCompletion) throws { try rewriteCompletedTrip(completion) }
    public func editCompletedTrip(_ completion: TripCompletion) throws { try rewriteCompletedTrip(completion) }

    private func rewriteCompletedTrip(_ completion: TripCompletion) throws {
        try database.writer.write { db in
            guard var trip = try TripRecord.fetchOne(db, key: completion.tripID) else { throw PersistenceError.activeTripMissing }
            guard completion.endedAt >= try Self.date(trip.startedAt) else { throw PersistenceError.invalidState("El fin no puede ser anterior al inicio.") }
            if !completion.participantIDs.isEmpty {
                guard completion.participantIDs.count == trip.totalPeople, completion.participantIDs.first == SystemIDs.owner else { throw PersistenceError.invalidState("El propietario debe ser el participante 0.") }
                trip.accountingMode = "named"
            } else { trip.accountingMode = "anonymous" }
            try db.execute(sql: "DELETE FROM LedgerEntry WHERE tripID = ? AND kind = 'charge'", arguments: [trip.id])
            try db.execute(sql: "DELETE FROM ManualExpense WHERE tripID = ?", arguments: [trip.id])
            try db.execute(sql: "DELETE FROM TripParticipant WHERE tripID = ?", arguments: [trip.id])
            let updated = iso.string(from: completion.endedAt)
            for expense in completion.expenses where expense.amount.cents > 0 {
                try db.execute(sql: "INSERT INTO ManualExpense (id,tripID,label,kind,amountCents,createdAt,updatedAt) VALUES (?,?,?,?,?,?,?)", arguments: [UUID().uuidString, trip.id, expense.label, expense.kind, expense.amount.cents, updated, updated])
            }
            for (index, personID) in completion.participantIDs.enumerated() {
                try db.execute(sql: "INSERT INTO TripParticipant (tripID,personID,role,sortOrder) VALUES (?,?,?,?)", arguments: [trip.id, personID, index == 0 ? "driver" : "passenger", index])
            }
            try Self.insertDerivedCharges(db: db, trip: trip, participantIDs: completion.participantIDs, expenses: completion.expenses, occurredAt: updated)
            try db.execute(sql: "UPDATE Trip SET status='completed',endedAt=?,accountingMode=?,updatedAt=?,revision=revision+1 WHERE id=?", arguments: [updated, trip.accountingMode, updated, trip.id])
            try db.execute(sql: "DELETE FROM ActiveTripState WHERE tripID = ?", arguments: [trip.id])
        }
    }

    public func deleteTrip(id: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM LedgerEntry WHERE tripID = ? AND kind = 'charge'", arguments: [id])
            try db.execute(sql: "DELETE FROM Trip WHERE id = ?", arguments: [id])
        }
    }

    @discardableResult
    public func recordPayment(personID: String, allocations: [(groupID: String, amount: MoneyCents)], occurredAt: Date, note: String?) throws -> String {
        guard !allocations.isEmpty, allocations.allSatisfy({ $0.amount.cents > 0 }) else { throw PersistenceError.invalidState("El pago debe tener asignaciones positivas.") }
        let batchID = UUID().uuidString
        let date = iso.string(from: occurredAt)
        let month = AccountingPeriod.accountingMonth(of: occurredAt, in: accountingTimeZone)
        try database.writer.write { db in
            try db.execute(sql: "INSERT INTO PaymentBatch (id,personID,occurredAt,note,createdAt) VALUES (?,?,?,?,?)", arguments: [batchID, personID, date, note, date])
            for allocation in allocations {
                try db.execute(sql: "INSERT INTO LedgerEntry (id,kind,debtorID,creditorID,amountCents,groupID,paymentBatchID,occurredAt,accountingMonth,createdAt,note) VALUES (?,'payment',?,?,?,?,?,?,?,?,?)", arguments: [UUID().uuidString, personID, SystemIDs.owner, allocation.amount.cents, allocation.groupID, batchID, date, month, date, note])
            }
        }
        return batchID
    }

    public func undoPayment(batchID: String) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM LedgerEntry WHERE paymentBatchID = ?", arguments: [batchID])
            try db.execute(sql: "DELETE FROM PaymentBatch WHERE id = ?", arguments: [batchID])
        }
    }

    public func balances() throws -> [BalanceSummary] {
        try database.writer.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT e.debtorID, p.name AS personName, e.groupID, g.name AS groupName,
                       SUM(CASE WHEN e.kind='charge' THEN e.amountCents ELSE -e.amountCents END) AS balanceCents
                FROM LedgerEntry e JOIN Person p ON p.id=e.debtorID JOIN \"Group\" g ON g.id=e.groupID
                GROUP BY e.debtorID,e.groupID ORDER BY p.name,g.createdAt,g.id
                """)
            return rows.map { BalanceSummary(personID: $0["debtorID"], personName: $0["personName"], groupID: $0["groupID"], groupName: $0["groupName"], balanceCents: $0["balanceCents"]) }
        }
    }

    public func monthlyStatement(personID: String, month: String) throws -> MonthlyStatement {
        try database.writer.read { db in
            let records = try LedgerEntryRecord.filter(Column("debtorID") == personID || Column("creditorID") == personID).fetchAll(db)
            let entries = try records.map { record in
                LedgerEntry(id: record.id, kind: record.kind == "charge" ? .charge : .payment, debtorID: PersonID(record.debtorID), creditorID: PersonID(record.creditorID), amountCents: MoneyCents(cents: record.amountCents), groupID: GroupID(record.groupID), tripID: record.tripID.map(TripID.init), paymentBatchID: record.paymentBatchID.map(PaymentBatchID.init), occurredAt: try Self.date(record.occurredAt))
            }
            return try MonthlyStatement.build(entries: entries, person: PersonID(personID), forMonth: month, in: accountingTimeZone)
        }
    }

    public func exportBackup(now: Date = Date()) throws -> Data {
        let document = try database.writer.read { db -> BackupDocument in
            guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Trip WHERE status IN ('active','interrupted')") == 0 else { throw PersistenceError.invalidBackup("Termina o descarta el viaje activo antes de exportar.") }
            return BackupDocument(schemaVersion: 1, exportedAt: iso.string(from: now), accountingTimeZone: "Europe/Madrid", vehicles: try VehicleRecord.fetchAll(db), consumptionProfiles: try ConsumptionProfileRecord.fetchAll(db), fuelPrices: try FuelPriceRecord.fetchAll(db), people: try PersonRecord.fetchAll(db), groups: try GroupRecord.fetchAll(db), groupMembers: try GroupMemberRecord.fetchAll(db), trips: try TripRecord.filter(Column("status") == "completed").fetchAll(db), tripParticipants: try TripParticipantRecord.fetchAll(db), manualExpenses: try ManualExpenseRecord.fetchAll(db), paymentBatches: try PaymentBatchRecord.fetchAll(db), payments: try LedgerEntryRecord.filter(Column("kind") == "payment").fetchAll(db))
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    public func importBackup(_ data: Data) throws {
        let document: BackupDocument
        do { document = try JSONDecoder().decode(BackupDocument.self, from: data) } catch { throw PersistenceError.invalidBackup("El archivo no es un backup EuroGas válido.") }
        guard document.schemaVersion == 1, document.accountingTimeZone == "Europe/Madrid", document.people.filter(\.isOwner).count == 1, document.groups.filter(\.isUngrouped).count == 1, document.trips.allSatisfy({ $0.status == "completed" }) else { throw PersistenceError.invalidBackup("El backup no cumple los invariantes de la versión 1.") }
        try database.writer.write { db in
            for table in ["LedgerEntry","PaymentBatch","ActiveTripState","ManualExpense","TripParticipant","Trip","GroupMember","FuelPrice","ConsumptionProfile","Vehicle","Group","Person"] { try db.execute(sql: "DELETE FROM \"\(table)\"") }
            for value in document.vehicles { try value.insert(db) }
            for value in document.consumptionProfiles { try value.insert(db) }
            for value in document.fuelPrices { try value.insert(db) }
            for value in document.people { try value.insert(db) }
            for value in document.groups { try value.insert(db) }
            for value in document.groupMembers { try value.insert(db) }
            for value in document.trips { try value.insert(db) }
            for value in document.tripParticipants { try value.insert(db) }
            for value in document.manualExpenses { try value.insert(db) }
            for value in document.paymentBatches { try value.insert(db) }
            for value in document.payments where value.kind == "payment" { try value.insert(db) }
            for trip in document.trips where trip.accountingMode == "named" {
                let participants = document.tripParticipants.filter { $0.tripID == trip.id }.sorted { $0.sortOrder < $1.sortOrder }.map(\.personID)
                let expenses = document.manualExpenses.filter { $0.tripID == trip.id }.map { ExpenseInput(label: $0.label, kind: $0.kind, amount: MoneyCents(cents: $0.amountCents)) }
                try Self.insertDerivedCharges(db: db, trip: trip, participantIDs: participants, expenses: expenses, occurredAt: trip.endedAt ?? trip.startedAt)
            }
        }
    }

    public func exportCSV() throws -> CSVExport {
        let trips = try completedTrips()
        let balances = try balances()
        let tripLines = ["id,started_at,distance_m,energy_cost_cents,status"] + trips.map { [Self.csv($0.id),Self.csv($0.startedAt),String($0.acceptedDistanceMeters),String($0.energyCostCents),$0.status].joined(separator: ",") }
        let accountLines = ["person,group,balance_cents"] + balances.map { [Self.csv($0.personName),Self.csv($0.groupName),String($0.balanceCents)].joined(separator: ",") }
        return CSVExport(trips: tripLines.joined(separator: "\r\n") + "\r\n", accounts: accountLines.joined(separator: "\r\n") + "\r\n")
    }

    private static func insertDerivedCharges(db: Database, trip: TripRecord, participantIDs: [String], expenses: [ExpenseInput], occurredAt: String) throws {
        guard trip.accountingMode == "named", participantIDs.count == trip.totalPeople else { return }
        let extras = expenses.reduce(Int64.zero) { $0 + $1.amount.cents }
        let total = MoneyCents(cents: trip.energyCostCents + extras)
        let split = try SplitEngine.split(total: total, people: trip.totalPeople, rule: trip.splitRule == "everyone" ? .everyone : .passengersOnly)
        for index in participantIDs.indices where index > 0 && split.shares[index].cents > 0 {
            try db.execute(sql: "INSERT INTO LedgerEntry (id,kind,debtorID,creditorID,amountCents,groupID,tripID,occurredAt,accountingMonth,createdAt) VALUES (?,'charge',?,?,?,?,?,?,?,?)", arguments: [UUID().uuidString, participantIDs[index], SystemIDs.owner, split.shares[index].cents, trip.groupID, trip.id, occurredAt, trip.accountingMonth, occurredAt])
        }
    }

    private static func decimal(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
    private static func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try JSONEncoder().encode(value), as: UTF8.self) }
    private static func decode<T: Decodable>(_ text: String) throws -> T { try JSONDecoder().decode(T.self, from: Data(text.utf8)) }
    private static func date(_ text: String) throws -> Date { guard let date = ISO8601DateFormatter().date(from: text) else { throw PersistenceError.invalidState("Fecha persistida inválida.") }; return date }
    private static func phaseString(_ phase: TripPhase) -> String { switch phase { case .starting: "starting"; case .tracking: "tracking"; case .paused: "paused"; case .interrupted: "interrupted"; case .finishing: "finishing"; default: "unsupported" } }
    private static func phase(_ text: String) -> TripPhase? { switch text { case "starting": .starting; case "tracking": .tracking; case "paused": .paused(.user); case "interrupted": .interrupted; case "finishing": .finishing; default: nil } }
    private static func csv(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
}
