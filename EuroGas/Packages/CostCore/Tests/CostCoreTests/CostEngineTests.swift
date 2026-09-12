import XCTest
@testable import CostCore

final class CostEngineTests: XCTestCase {
    func testCanonicalCosts() throws {
        XCTAssertEqual(try CostEngine.calculate(CostInputs(distanceMeters: 100000, consumptionPer100: Decimal(string: "6")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499))).energyCostCents.cents, 899)
        let result = try CostEngine.calculate(CostInputs(distanceMeters: 355000, consumptionPer100: Decimal(string: "6.1")!, realWorldFactor: Decimal(string: "1.20")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499)))
        XCTAssertEqual(result.effectiveConsumption, Decimal(string: "7.32")!)
        XCTAssertEqual(result.energyUnits, Decimal(string: "25.986")!)
        XCTAssertEqual(result.energyCostEUR, Decimal(string: "38.953014")!)
        XCTAssertEqual(result.energyCostCents.cents, 3895)
        XCTAssertEqual(try CostEngine.calculate(CostInputs(distanceMeters: 100000, consumptionPer100: Decimal(string: "18")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 200))).energyCostCents.cents, 360)
        let manual = try CostEngine.calculate(
            try CostInputs(
                distanceMeters: 100000,
                consumptionPer100: Decimal(string: "6")!,
                unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499),
                manualExpenses: [MoneyCents(cents: 250)]
            )
        )
        XCTAssertEqual(manual.energyCostCents.cents, 899)
        XCTAssertEqual(manual.extrasCents.cents, 250)
        XCTAssertEqual(manual.totalCents.cents, 1149)
    }

    func testAccumulatingSegmentsMatchesTotalDistanceExactly() throws {
        let distances = [12000.0, 33000.0, 71000.0, 49000.0, 90000.0, 100000.0]
        let segments = try CostEngine.calculate(segmentDistancesMeters: distances, consumptionPer100: Decimal(string: "6.1")!, realWorldFactor: Decimal(string: "1.20")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499))
        let total = try CostEngine.calculate(try CostInputs(distanceMeters: distances.reduce(0, +), consumptionPer100: Decimal(string: "6.1")!, realWorldFactor: Decimal(string: "1.20")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499)))
        XCTAssertEqual(segments.energyUnits, total.energyUnits)
        XCTAssertEqual(segments.energyCostEUR, total.energyCostEUR)
        XCTAssertEqual(segments.energyCostCents, total.energyCostCents)
    }

    func testInvalidPriceThrowsTypedError() {
        XCTAssertThrowsError(try CostInputs(distanceMeters: 1, consumptionPer100: 1, unitPriceMilliEUR: .zero)) { error in
            XCTAssertEqual(error as? CostCoreError, .nonPositivePrice)
        }
    }

    func testInvalidConsumptionThrowsTypedError() {
        XCTAssertThrowsError(try CostInputs(distanceMeters: 1, consumptionPer100: 0, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1))) { error in
            XCTAssertEqual(error as? CostCoreError, .nonPositiveConsumption)
        }
    }

    func testInvalidFactorThrowsTypedError() {
        XCTAssertThrowsError(try CostInputs(distanceMeters: 1, consumptionPer100: 1, realWorldFactor: 0, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1))) { error in
            XCTAssertEqual(error as? CostCoreError, .nonPositiveFactor)
        }
    }

    func testInvalidDistancesThrowTypedError() {
        for distance in [-1.0, .infinity, .nan] {
            XCTAssertThrowsError(try CostInputs(distanceMeters: distance, consumptionPer100: 1, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1))) { error in
                XCTAssertEqual(error as? CostCoreError, .invalidDistance)
            }
        }
    }

    func testNegativeSegmentThrowsTypedError() {
        XCTAssertThrowsError(try CostEngine.calculate(segmentDistancesMeters: [100, -1], consumptionPer100: 1, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1))) { error in
            XCTAssertEqual(error as? CostCoreError, .invalidDistance)
        }
    }

    func testZeroDistanceRemainsValid() throws {
        let result = try CostEngine.calculate(try CostInputs(distanceMeters: 0, consumptionPer100: 1, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1)))
        XCTAssertEqual(result.energyUnits, 0)
        XCTAssertEqual(result.energyCostCents, .zero)
    }
}
