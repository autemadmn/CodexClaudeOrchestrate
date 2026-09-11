import Foundation

/// Errores producidos al analizar un importe o precio localizado.
public enum MoneyParsingError: Error, Equatable, LocalizedError {
    case empty
    case thousandsSeparator
    case multipleDecimalSeparators
    case tooManyFractionDigits(maximum: Int)
    case negative
    case missingDigits
    case nonNumericCharacter(Character)
    case outOfRange

    public var errorDescription: String? {
        switch self {
        case .empty: return "Introduce un importe; el valor no puede estar vacío."
        case .thousandsSeparator: return "Elimina el separador de millares y usa sólo el separador decimal de tu región."
        case .multipleDecimalSeparators: return "Usa un único separador decimal."
        case let .tooManyFractionDigits(maximum): return "Usa como máximo \(maximum) decimales."
        case .negative: return "Introduce un valor cero o positivo."
        case .missingDigits: return "Escribe dígitos antes y después del separador decimal."
        case let .nonNumericCharacter(character): return "El carácter '\(character)' no es numérico; corrige el valor."
        case .outOfRange: return "El valor está fuera del rango permitido; introduce una cifra menor."
        }
    }
}

/// Redondea un Decimal con la regla decimal half-up (5 se aleja de cero).
public func roundHalfUp(_ value: Decimal, scale: Int = 0) -> Decimal {
    var input = value
    var result = Decimal.zero
    NSDecimalRound(&result, &input, scale, .plain)
    return result
}

private func parseLocalizedDecimal(_ text: String, locale: Locale, maximumFractionDigits: Int) throws -> Int64 {
    let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedText.isEmpty else { throw MoneyParsingError.empty }

    let separatorText = locale.decimalSeparator ?? "."
    let groupingText = locale.groupingSeparator ?? ""
    guard let separator = separatorText.first,
          separatorText.count == 1 else {
        throw MoneyParsingError.nonNumericCharacter(separatorText.first ?? ".")
    }
    if !groupingText.isEmpty, groupingText.count != 1 {
        throw MoneyParsingError.nonNumericCharacter(groupingText.first ?? ".")
    }
    if !groupingText.isEmpty, normalizedText.contains(groupingText) {
        throw MoneyParsingError.thousandsSeparator
    }
    if normalizedText.hasPrefix("-") {
        throw MoneyParsingError.negative
    }

    let parts = normalizedText.split(separator: separator, omittingEmptySubsequences: false)
    guard parts.count <= 2 else { throw MoneyParsingError.multipleDecimalSeparators }
    if parts.count == 2, (parts[0].isEmpty || parts[1].isEmpty) {
        throw MoneyParsingError.missingDigits
    }
    let fraction = parts.count == 2 ? String(parts[1]) : ""
    guard fraction.count <= maximumFractionDigits else {
        throw MoneyParsingError.tooManyFractionDigits(maximum: maximumFractionDigits)
    }
    for character in normalizedText {
        if character == separator { continue }
        guard character.isASCII, character.isNumber else {
            throw MoneyParsingError.nonNumericCharacter(character)
        }
    }

    let integerPart = String(parts[0])
    let digits = integerPart + fraction.padding(toLength: maximumFractionDigits, withPad: "0", startingAt: 0)
    guard let value = Int64(digits) else { throw MoneyParsingError.outOfRange }
    return value
}

public struct MoneyCents: Equatable, Comparable, Hashable, Codable, Sendable {
    public static let zero = MoneyCents(cents: 0)
    // Este par etiquetado es la única frontera Int64 del contrato monetario.
    public let cents: Int64

    public init(cents: Int64) { self.cents = cents }

    public init(parsing text: String, locale: Locale) throws {
        self.init(cents: try parseLocalizedDecimal(text, locale: locale, maximumFractionDigits: 2))
    }

    public static func parse(_ text: String, locale: Locale) throws -> Self {
        try Self(parsing: text, locale: locale)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.cents < rhs.cents }
}

public struct UnitPriceMilliEUR: Equatable, Comparable, Hashable, Codable, Sendable {
    public static let zero = UnitPriceMilliEUR(milliEUR: 0)
    // Este par etiquetado es la única frontera Int64 del contrato de precios.
    public let milliEUR: Int64

    public init(milliEUR: Int64) { self.milliEUR = milliEUR }

    public init(parsing text: String, locale: Locale) throws {
        self.init(milliEUR: try parseLocalizedDecimal(text, locale: locale, maximumFractionDigits: 3))
    }

    public static func parse(_ text: String, locale: Locale) throws -> Self {
        try Self(parsing: text, locale: locale)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.milliEUR < rhs.milliEUR }
}
