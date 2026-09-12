# EuroGas — contratos congelados

Este documento transcribe únicamente declaraciones copiadas literalmente del código fuente. El estado de construcción de Swift es **UNVERIFIED-BUILD**: este documento no afirma que el código compile ni que se haya ejecutado.

## API pública de CostCore

### CostCore.swift

```swift
public let costModelVersion = 1
```

### Models/Money.swift

```swift
public func roundHalfUp(_ value: Decimal, scale: Int = 0) -> Decimal
public struct MoneyCents: Equatable, Comparable, Hashable, Codable, Sendable {
    public static let zero = MoneyCents(cents: 0)
    public let cents: Int64
    public init(cents: Int64)
    public init(parsing text: String, locale: Locale) throws
    public static func parse(_ text: String, locale: Locale) throws -> Self
    public static func < (lhs: Self, rhs: Self) -> Bool
}
public struct UnitPriceMilliEUR: Equatable, Comparable, Hashable, Codable, Sendable {
    public static let zero = UnitPriceMilliEUR(milliEUR: 0)
    public let milliEUR: Int64
    public init(milliEUR: Int64)
    public init(parsing text: String, locale: Locale) throws
    public static func parse(_ text: String, locale: Locale) throws -> Self
    public static func < (lhs: Self, rhs: Self) -> Bool
}
```

### Models/CostCoreError.swift

```swift
public enum CostCoreError: Error, Equatable, LocalizedError {
    case nonPositivePrice
    case nonPositiveConsumption
    case nonPositiveFactor
    case invalidDistance
    case participantCountOutOfRange(Int)
    case passengersOnlyWithoutPassengers
    case negativeTotal
}
```

### Cost/CostEngine.swift

```swift
public struct CostInputs: Equatable, Sendable {
    public let distanceMeters: Double
    public let consumptionPer100: Decimal
    public let realWorldFactor: Decimal
    public let unitPriceMilliEUR: UnitPriceMilliEUR
    public let manualExpenses: [MoneyCents]
    public init(
        distanceMeters: Double,
        consumptionPer100: Decimal,
        realWorldFactor: Decimal = Decimal(1),
        unitPriceMilliEUR: UnitPriceMilliEUR,
        manualExpenses: [MoneyCents] = []
    ) throws
}
public struct CostBreakdown: Equatable, Sendable {
    public let effectiveConsumption: Decimal
    public let energyUnits: Decimal
    public let energyCostEUR: Decimal
    public let energyCostCents: MoneyCents
    public let extrasCents: MoneyCents
    public let totalCents: MoneyCents
}
public enum CostEngine {
    public static func calculate(_ input: CostInputs) throws -> CostBreakdown
    public static func calculate(
        segmentDistancesMeters: [Double],
        consumptionPer100: Decimal,
        realWorldFactor: Decimal = Decimal(1),
        unitPriceMilliEUR: UnitPriceMilliEUR,
        manualExpenses: [MoneyCents] = []
    ) throws -> CostBreakdown
}
```

### Split/SplitEngine.swift

```swift
public enum SplitRule: Equatable, Sendable { case everyone, passengersOnly }
public struct SplitResult: Equatable, Sendable {
    public let shares: [MoneyCents]
    public init(shares: [MoneyCents])
}
public enum SplitEngine {
    public static func split(total: MoneyCents, people: Int, rule: SplitRule) throws -> SplitResult
}
```

Invariante: `sum(shares) == total`; no existe `driverExtra`. Convención posicional: índice 0 = conductor; los índices restantes son pasajeros. Para total cero, no se crean asientos (`shares` vacío).

### Ledger/Identifiers.swift

```swift
public struct PersonID: Hashable, Codable, Sendable, Comparable {
    public let rawValue: String
    public init(_ rawValue: String)
    public static func < (lhs: Self, rhs: Self) -> Bool
}
public struct GroupID: Hashable, Codable, Sendable, Comparable {
    public let rawValue: String
    public init(_ rawValue: String)
    public static func < (lhs: Self, rhs: Self) -> Bool
}
public struct TripID: Hashable, Codable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String)
}
public struct PaymentBatchID: Hashable, Codable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String)
}
```

### Ledger/LedgerEntry.swift

```swift
public struct LedgerEntry: Equatable, Sendable {
    public enum Kind: String, Sendable { case charge, payment }
    public let id: String
    public let kind: Kind
    public let debtorID: PersonID
    public let creditorID: PersonID
    public let amountCents: MoneyCents
    public let groupID: GroupID
    public let tripID: TripID?
    public let paymentBatchID: PaymentBatchID?
    public let occurredAt: Date
    public init(id: String, kind: Kind, debtorID: PersonID, creditorID: PersonID, amountCents: MoneyCents, groupID: GroupID, tripID: TripID? = nil, paymentBatchID: PaymentBatchID? = nil, occurredAt: Date)
}
```

### Ledger/LedgerMath.swift

```swift
public enum LedgerMath {
    public static func balance(entries: [LedgerEntry], person: PersonID, group: GroupID) -> MoneyCents
    public static func pending(entries: [LedgerEntry], person: PersonID, group: GroupID) -> MoneyCents
    public static func credit(entries: [LedgerEntry], person: PersonID, group: GroupID) -> MoneyCents
    public static func netAcrossGroups(entries: [LedgerEntry], person: PersonID) -> MoneyCents
}
```

`LedgerMath.netAcrossGroups` es sólo diagnóstico. No puede mostrarse como saldo por grupo; para un grupo deben usarse `pending` o `credit` (§7.2).

### Ledger/AccountingPeriod.swift

```swift
public enum AccountingPeriod {
    public static func bounds(forMonth month: String, in timeZone: TimeZone) throws -> (start: Date, end: Date)
    public static func accountingMonth(of date: Date, in timeZone: TimeZone) -> String
}
```

### Ledger/FreeWindow.swift

```swift
public enum FreeWindow {
    public static func visibleRange(now: Date, in timeZone: TimeZone) throws -> (start: Date, end: Date)
}
```

### Ledger/MonthlyStatement.swift

```swift
public struct MonthlyStatement: Equatable, Sendable {
    public let opening: MoneyCents
    public let charges: MoneyCents
    public let payments: MoneyCents
    public let closing: MoneyCents
    public init(opening: MoneyCents, charges: MoneyCents, payments: MoneyCents)
    public init(entries: [LedgerEntry], person: PersonID, forMonth month: String, in timeZone: TimeZone) throws
    public static func build(entries: [LedgerEntry], person: PersonID, forMonth month: String, in timeZone: TimeZone) throws -> Self
}
```

### Ledger/PaymentAllocationProposal.swift

```swift
public struct GroupPending: Equatable, Sendable {
    public let groupID: GroupID
    public let pending: MoneyCents
    public let createdAt: Date
    public let id: String
    public init(groupID: GroupID, pending: MoneyCents, createdAt: Date, id: String)
}
public enum PaymentAllocationProposal {
    public static func propose(amount: MoneyCents, pendingByGroup: [GroupPending]) throws -> [(groupID: GroupID, amount: MoneyCents)]
    public static func propose(amount: MoneyCents, pendingByGroup: [GroupPending], creditGroupID: GroupID?) throws -> [(groupID: GroupID, amount: MoneyCents)]
}
```

`PaymentAllocationProposal` es matemática local: no ejecuta pagos reales, no hace billing y no usa credenciales.

## Errores tipados existentes

```swift
public enum MoneyParsingError: Error, Equatable, LocalizedError {
    case empty
    case thousandsSeparator
    case multipleDecimalSeparators
    case tooManyFractionDigits(maximum: Int)
    case negative
    case missingDigits
    case nonNumericCharacter(Character)
    case outOfRange
}
public enum CostCoreError: Error, Equatable, LocalizedError {
    case nonPositivePrice
    case nonPositiveConsumption
    case nonPositiveFactor
    case invalidDistance
    case participantCountOutOfRange(Int)
    case passengersOnlyWithoutPassengers
    case negativeTotal
}
public enum PaymentAllocationError: Error, Equatable { case nonPositiveAmount, missingCreditGroup, invalidCreditGroup }
public enum AccountingPeriodError: Error, Equatable { case invalidMonth, unavailableTimeZone(String) }
public enum FreeWindowError: Error, Equatable { case unavailableTimeZone(String) }
```

Casos reales: `MoneyParsingError` cubre entrada vacía, separador de millares, separadores decimales múltiples, exceso de decimales, negativos, dígitos ausentes, caracteres no numéricos y fuera de rango. `CostCoreError` cubre precio, consumo, factor o distancia inválidos, participantes fuera de 1–8, pasajeros sin pasajeros y total negativo. `PaymentAllocationError` cubre importe no positivo, grupo de crédito ausente y grupo de crédito inválido. `AccountingPeriodError` cubre mes inválido y zona horaria no disponible. `FreeWindowError` cubre zona horaria no disponible.

## Contratos pendientes

`LocationProvider`, `RoutingService`, `PurchaseAccess` y `ActiveTripState` permanecen **PENDIENTE**.

## Esquema v1 y propiedad de archivos

La única definición canónica del esquema v1 es `EuroGas/Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql`. Está existente y verificada por el arnés SQLite. Cualquier binding futuro, GRDB u otro, debe ejecutar ese mismo texto SQL sin reescribirlo, conforme a DEC-005 y DEC-008. No se cita ninguna otra ruta de DDL.

| Archivo o área | Propietario | Estado |
|---|---|---|
| `EuroGas/Packages/CostCore/Sources/CostCore/Models/` | Codex | API monetaria y errores |
| `EuroGas/Packages/CostCore/Sources/CostCore/Cost/` | Codex | Contratos de cálculo |
| `EuroGas/Packages/CostCore/Sources/CostCore/Split/` | Codex | Contratos de reparto |
| `EuroGas/Packages/CostCore/Sources/CostCore/Ledger/` | Codex | Libro mayor y periodos |
| `EuroGas/Packages/CostCore/Tests/` | Codex | Tests del núcleo; estado Swift UNVERIFIED-BUILD |
| `EuroGas/Packages/Persistence/Sources/Persistence/Migrations/` | Codex | Esquema v1 canónico |
| `EuroGas/Packages/Persistence/Tests/` | Codex | Arnés SQLite |
| `EuroGas/docs/CONTRACTS.md` | Codex | Documentación contractual |
| `EuroGas/docs/STATUS.md` | Codex | Estado y evidencias |
| `EuroGas/docs/FIELD_TESTS.md` | Codex | Procedimientos externos |
