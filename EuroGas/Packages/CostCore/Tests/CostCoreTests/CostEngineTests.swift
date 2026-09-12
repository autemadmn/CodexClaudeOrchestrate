import XCTest
@testable import CostCore

final class CostEngineTests: XCTestCase {
    func testCanonicalCosts() {
        XCTAssertEqual(CostEngine.calculate(CostInput(distanceMeters: 100000, consumptionPer100: Decimal(string: "6")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499))).energyCostCents.cents, 899)
        let result = CostEngine.calculate(CostInput(distanceMeters: 355000, consumptionPer100: Decimal(string: "6.1")!, realWorldFactor: Decimal(string: "1.20")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499)))
        XCTAssertEqual(result.effectiveConsumption, Decimal(string: "7.32")!)
        XCTAssertEqual(result.energyUnits, Decimal(string: "25.986")!)
        XCTAssertEqual(result.energyCostEUR, Decimal(string: "38.953014")!)
        XCTAssertEqual(result.energyCostCents.cents, 3895)
        XCTAssertEqual(CostEngine.calculate(CostInput(distanceMeters: 100000, consumptionPer100: Decimal(string: "18")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 200))).energyCostCents.cents, 360)
        XCTAssertEqual(CostEngine.calculate(CostInput(distanceMeters: 100000, consumptionPer100: Decimal(string: "6")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499), manualExpenses: [MoneyCents(cents: 250)])).totalCents.cents, 1149)
    }

    func testAccumulatingSegmentsMatchesTotalDistanceExactly() {
        let distances = [12000.0, 33000.0, 71000.0, 49000.0, 90000.0, 100000.0]
        let segments = CostEngine.calculate(segmentDistancesMeters: distances, consumptionPer100: Decimal(string: "6.1")!, realWorldFactor: Decimal(string: "1.20")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499))
        let total = CostEngine.calculate(CostInput(distanceMeters: distances.reduce(0, +), consumptionPer100: Decimal(string: "6.1")!, realWorldFactor: Decimal(string: "1.20")!, unitPriceMilliEUR: UnitPriceMilliEUR(milliEUR: 1499)))
        XCTAssertEqual(segments.energyUnits, total.energyUnits)
        XCTAssertEqual(segments.energyCostEUR, total.energyCostEUR)
        XCTAssertEqual(segments.energyCostCents, total.energyCostCents)
    }
}
