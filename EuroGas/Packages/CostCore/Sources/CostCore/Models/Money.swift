import Foundation

/// Errors produced while parsing a localized monetary or unit-price value.
public enum MoneyParsingError: Error, Equatable, LocalizedError {
    case empty
    case thousandsSeparator
    case multipleDecimalSeparators
    case tooManyFractionDigits(maximum: Int)
    case negative
    case nonNumericCharacter(Character)
    case outOfRange

    public var errorDescription: String? {
        switch self {
        case .empty: return "Introduce un importe; el valor no puede estar vacío."
        case .thousandsSeparator: return "Elimina el separador de millares y usa sólo el separador decimal de tu región."
        case .multipleDecimalSeparators: return "Usa un único separador decimal."
        case let .tooManyFractionDigits(maximum): return "Usa como máximo \(maximum) decimales."
        case .negative: return "Introduce un valor cero o positivo."
        case let .nonNumericCharacter(character): return "El carácter '\(character)' no es numérico; corrige el valor."
        case .outOfRange: return "El valor está fuera del rango permitido; introduce una cifra menor."
        }
    }
}

/// Descriptive compatibility name for callers that refer to the shared parser error.
public typealias MonetaryParseError = MoneyParsingError

/// Rounds a Decimal using decimal half-up (5 rounds away from zero).
public func roundHalfUp(_ value: Decimal, scale: Int = 0) -> Decimal {
    var input = value
    var result = Decimal.zero
    NSDecimalRound(&result, &input, scale, .plain)
    return result
}

private func parseLocalizedDecimal(_ text: String, locale: Locale, maximumFractionDigits: Int) throws -> Int64 {
    guard !text.isEmpty else { throw MonetaryParseError.empty }
    let separator = locale.decimalSeparator ?? "."
    let grouping = locale.groupingSeparator ?? ""
    if !grouping.isEmpty, text.contains(grouping) { throw MonetaryParseError.thousandsSeparator }
    if text.contains("-") { throw MonetaryParseError.negative }

    let parts = text.split(separator: Character(separator), omittingEmptySubsequences: false)
    guard parts.count <= 2 else { throw MonetaryParseError.multipleDecimalSeparators }
    guard !parts[0].isEmpty else { throw MonetaryParseError.nonNumericCharacter(separator.first ?? ".") }
    let fraction = parts.count == 2 ? String(parts[1]) : ""
    if parts.count == 2, fraction.isEmpty {
        throw MonetaryParseError.nonNumericCharacter(Character(separator))
    }
    guard fraction.count <= maximumFractionDigits else {
        throw MonetaryParseError.tooManyFractionDigits(maximum: maximumFractionDigits)
    }
    for character in text {
        if character == Character(separator) { continue }
        guard character.isASCII, character.isNumber else {
            throw MonetaryParseError.nonNumericCharacter(character)
        }
    }

    let integerPart = String(parts[0])
    let digits = integerPart + fraction.padding(toLength: maximumFractionDigits, withPad: "0", startingAt: 0)
    guard let value = Int64(digits) else { throw MonetaryParseError.outOfRange }
    return value
}

public struct MoneyCents: Equatable, Comparable, Hashable, Codable, Sendable {
    public static let zero = MoneyCents(0)
    public let value: Int64
    public var rawValue: Int64 { value }

    public init(_ value: Int64) { self.value = value }

    public init(parsing text: String, locale: Locale = .current) throws {
        self.init(try parseLocalizedDecimal(text, locale: locale, maximumFractionDigits: 2))
    }

    public static func parse(_ text: String, locale: Locale = .current) throws -> Self {
        try Self(parsing: text, locale: locale)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct UnitPriceMilliEUR: Equatable, Comparable, Hashable, Codable, Sendable {
    public static let zero = UnitPriceMilliEUR(0)
    public let value: Int64
    public var rawValue: Int64 { value }

    public init(_ value: Int64) { self.value = value }

    public init(parsing text: String, locale: Locale = .current) throws {
        self.init(try parseLocalizedDecimal(text, locale: locale, maximumFractionDigits: 3))
    }

    public static func parse(_ text: String, locale: Locale = .current) throws -> Self {
        try Self(parsing: text, locale: locale)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
