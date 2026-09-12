import Foundation

public struct CostInput: Equatable, Sendable {
    public let distanceMeters: Double
    public let consumptionPer100: Decimal
    public let realWorldFactor: Decimal
    public let unitPriceMilliEUR: UnitPriceMilliEUR
    public let manualExpenses: [MoneyCents]

    public init(distanceMeters: Double, consumptionPer100: Decimal, realWorldFactor: Decimal = Decimal(string: "1")!, unitPriceMilliEUR: UnitPriceMilliEUR, manualExpenses: [MoneyCents] = []) {
        precondition(distanceMeters.isFinite && distanceMeters >= 0)
        precondition(consumptionPer100 > 0 && realWorldFactor > 0 && unitPriceMilliEUR.milliEUR > 0)
        self.distanceMeters = distanceMeters
        self.consumptionPer100 = consumptionPer100
        self.realWorldFactor = realWorldFactor
        self.unitPriceMilliEUR = unitPriceMilliEUR
        self.manualExpenses = manualExpenses
    }
}

public struct CostResult: Equatable, Sendable {
    public let effectiveConsumption: Decimal
    public let energyUnits: Decimal
    public let energyCostEUR: Decimal
    public let energyCostCents: MoneyCents
    public let totalCents: MoneyCents
}

public enum CostEngine {
    public static func calculate(_ input: CostInput) -> CostResult {
        makeResult(energyUnits: energy(for: input.distanceMeters, consumption: input.consumptionPer100, factor: input.realWorldFactor), input: input)
    }

    public static func calculate(segmentDistancesMeters: [Double], consumptionPer100: Decimal, realWorldFactor: Decimal = Decimal(string: "1")!, unitPriceMilliEUR: UnitPriceMilliEUR, manualExpenses: [MoneyCents] = []) -> CostResult {
        precondition(segmentDistancesMeters.allSatisfy { $0.isFinite && $0 >= 0 })
        let input = CostInput(distanceMeters: segmentDistancesMeters.reduce(0, +), consumptionPer100: consumptionPer100, realWorldFactor: realWorldFactor, unitPriceMilliEUR: unitPriceMilliEUR, manualExpenses: manualExpenses)
        let units = segmentDistancesMeters.reduce(Decimal.zero) { $0 + energy(for: $1, consumption: consumptionPer100, factor: realWorldFactor) }
        return makeResult(energyUnits: units, input: input)
    }

    private static func energy(for distanceMeters: Double, consumption: Decimal, factor: Decimal) -> Decimal {
        precondition(distanceMeters.isFinite && distanceMeters >= 0)
        guard let distance = Decimal(string: String(distanceMeters), locale: Locale(identifier: "en_US_POSIX")) else {
            preconditionFailure("distancia no convertible a Decimal")
        }
        return distance / 100000 * consumption * factor
    }

    private static func makeResult(energyUnits: Decimal, input: CostInput) -> CostResult {
        let effective = input.consumptionPer100 * input.realWorldFactor
        let energyCostEUR = energyUnits * Decimal(input.unitPriceMilliEUR.milliEUR) / 1000
        let cents = roundHalfUp(energyCostEUR * 100)
        let extras = input.manualExpenses.reduce(Int64(0)) { $0 + $1.cents }
        return CostResult(effectiveConsumption: effective, energyUnits: energyUnits, energyCostEUR: energyCostEUR,
                          energyCostCents: MoneyCents(cents: NSDecimalNumber(decimal: cents).int64Value),
                          totalCents: MoneyCents(cents: NSDecimalNumber(decimal: cents).int64Value + extras))
    }
}
