import Foundation

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
    ) throws {
        guard distanceMeters.isFinite && distanceMeters >= 0 else {
            throw CostCoreError.invalidDistance
        }
        guard consumptionPer100 > 0 else {
            throw CostCoreError.nonPositiveConsumption
        }
        guard realWorldFactor > 0 else {
            throw CostCoreError.nonPositiveFactor
        }
        guard unitPriceMilliEUR.milliEUR > 0 else {
            throw CostCoreError.nonPositivePrice
        }
        self.distanceMeters = distanceMeters
        self.consumptionPer100 = consumptionPer100
        self.realWorldFactor = realWorldFactor
        self.unitPriceMilliEUR = unitPriceMilliEUR
        self.manualExpenses = manualExpenses
    }
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
    public static func calculate(_ input: CostInputs) throws -> CostBreakdown {
        makeResult(
            energyUnits: try energy(
                for: input.distanceMeters,
                consumption: input.consumptionPer100,
                factor: input.realWorldFactor
            ),
            input: input
        )
    }

    public static func calculate(
        segmentDistancesMeters: [Double],
        consumptionPer100: Decimal,
        realWorldFactor: Decimal = Decimal(1),
        unitPriceMilliEUR: UnitPriceMilliEUR,
        manualExpenses: [MoneyCents] = []
    ) throws -> CostBreakdown {
        guard segmentDistancesMeters.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw CostCoreError.invalidDistance
        }
        let input = try CostInputs(
            distanceMeters: segmentDistancesMeters.reduce(0, +),
            consumptionPer100: consumptionPer100,
            realWorldFactor: realWorldFactor,
            unitPriceMilliEUR: unitPriceMilliEUR,
            manualExpenses: manualExpenses
        )
        let units = try segmentDistancesMeters.reduce(Decimal.zero) {
            $0 + (try energy(for: $1, consumption: consumptionPer100, factor: realWorldFactor))
        }
        return makeResult(energyUnits: units, input: input)
    }

    private static func energy(for distanceMeters: Double, consumption: Decimal, factor: Decimal) throws -> Decimal {
        guard distanceMeters.isFinite && distanceMeters >= 0 else {
            throw CostCoreError.invalidDistance
        }
        guard let distance = Decimal(string: String(distanceMeters), locale: Locale(identifier: "en_US_POSIX")) else {
            throw CostCoreError.invalidDistance
        }
        return distance / 100000 * consumption * factor
    }

    private static func makeResult(energyUnits: Decimal, input: CostInputs) -> CostBreakdown {
        let effective = input.consumptionPer100 * input.realWorldFactor
        let energyCostEUR = energyUnits * Decimal(input.unitPriceMilliEUR.milliEUR) / 1000
        let cents = roundHalfUp(energyCostEUR * 100)
        let extras = input.manualExpenses.reduce(Int64(0)) { $0 + $1.cents }
        let energyCents = MoneyCents(cents: NSDecimalNumber(decimal: cents).int64Value)
        let extrasCents = MoneyCents(cents: extras)
        return CostBreakdown(
            effectiveConsumption: effective,
            energyUnits: energyUnits,
            energyCostEUR: energyCostEUR,
            energyCostCents: energyCents,
            extrasCents: extrasCents,
            totalCents: MoneyCents(cents: energyCents.cents + extrasCents.cents)
        )
    }
}
