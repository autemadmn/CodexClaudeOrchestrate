# EuroGas — contratos congelados (estado real)

Este documento transcribe sólo símbolos públicos que existen literalmente en el código presente. La evidencia está en [STATUS.md](STATUS.md).

## API pública de CostCore

Archivo: `EuroGas/Packages/CostCore/Sources/CostCore/CostCore.swift`.

```swift
public let costModelVersion = 1
```

Archivo: `EuroGas/Packages/CostCore/Sources/CostCore/Models/Money.swift`.

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

`MoneyCents` representa importes finales y `UnitPriceMilliEUR` precios unitarios. No existen en el código actual `CostInputs`, `CostBreakdown`, `SplitRule` ni `SplitResult`; no se transcriben firmas inventadas.

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
```

## Contratos pendientes

Exigidos por CORE-7 §19.3, pero aún no son API disponible:

- `LocationProvider` — PENDIENTE.
- `RoutingService` — PENDIENTE.
- `PurchaseAccess` — PENDIENTE.
- `ActiveTripState` — PENDIENTE.

## Esquema v1 y propiedad de archivos

`EuroGas/Packages/CostCore/v1_initial.sql` es la única definición canónica del esquema v1 conforme a DEC-005. El archivo aún no existe y no se declara entregado.

| Archivo o área | Propietario | Estado |
|---|---|---|
| `EuroGas/Packages/CostCore/Sources/CostCore/` | Codex | Tipos monetarios y `costModelVersion` |
| `EuroGas/Packages/CostCore/Tests/` | Codex | Tests monetarios escritos; sin ejecución Swift local |
| `EuroGas/Packages/CostCore/Package.swift` | Codex | Paquete sin dependencias |
| `EuroGas/Packages/CostCore/v1_initial.sql` | Codex | No entregado; fuente SQL v1 única |
| `EuroGas/docs/CONTRACTS.md` | Codex | Documentación contractual |
| `EuroGas/docs/STATUS.md` | Codex | Estado y evidencias |
| `EuroGas/docs/FIELD_TESTS.md` | Codex | Procedimientos externos |
