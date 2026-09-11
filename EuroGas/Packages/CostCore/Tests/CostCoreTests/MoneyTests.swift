import Foundation
import XCTest
@testable import CostCore

final class MoneyTests: XCTestCase {
    func testLocalizedSpanishValuesUseDecimalSeparator() throws {
        let spanish = Locale(identifier: "es_ES")
        XCTAssertEqual(try UnitPriceMilliEUR(parsing: "1,499", locale: spanish).milliEUR, 1499)
        XCTAssertEqual(try MoneyCents(parsing: "14,99", locale: spanish).cents, 1499)
    }

    func testRoundHalfUpRoundsAtTheHalf() {
        XCTAssertEqual(roundHalfUp(Decimal(string: "8.994")!, scale: 2), Decimal(string: "8.99")!)
        XCTAssertEqual(roundHalfUp(Decimal(string: "8.995")!, scale: 2), Decimal(string: "9.00")!)
        XCTAssertEqual(roundHalfUp(Decimal(string: "-8.995")!, scale: 2), Decimal(string: "-9.00")!)
        XCTAssertEqual(roundHalfUp(Decimal(string: "899.4")!, scale: 0), Decimal(string: "899")!)
    }

    func testEveryDeclaredParsingErrorIsReachable() {
        let spanish = Locale(identifier: "es_ES")
        assertThrows(MoneyParsingError.thousandsSeparator) { try UnitPriceMilliEUR(parsing: "1.499", locale: spanish) }
        assertThrows(MoneyParsingError.multipleDecimalSeparators) { try UnitPriceMilliEUR(parsing: "1,4,9", locale: spanish) }
        assertThrows(MoneyParsingError.tooManyFractionDigits(maximum: 3)) { try UnitPriceMilliEUR(parsing: "1,4999", locale: spanish) }
        assertThrows(MoneyParsingError.tooManyFractionDigits(maximum: 2)) { try MoneyCents(parsing: "1,999", locale: spanish) }
        assertThrows(MoneyParsingError.negative) { try MoneyCents(parsing: "-1,5", locale: spanish) }
        assertThrows(MoneyParsingError.empty) { try MoneyCents(parsing: "", locale: spanish) }
        assertThrows(MoneyParsingError.empty) { try MoneyCents(parsing: " \t\n", locale: spanish) }
        assertThrows(MoneyParsingError.missingDigits) { try MoneyCents(parsing: "1,", locale: spanish) }
        assertThrows(MoneyParsingError.missingDigits) { try MoneyCents(parsing: ",5", locale: spanish) }
        assertThrows(MoneyParsingError.nonNumericCharacter("a")) { try MoneyCents(parsing: "1,a", locale: spanish) }
        assertThrows(MoneyParsingError.nonNumericCharacter("-")) { try MoneyCents(parsing: "1-2", locale: spanish) }
        assertThrows(MoneyParsingError.outOfRange) { try MoneyCents(parsing: "999999999999999999999999", locale: spanish) }
    }

    private func assertThrows<E: Error & Equatable>(_ expected: E, _ expression: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        do {
            try expression()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}
