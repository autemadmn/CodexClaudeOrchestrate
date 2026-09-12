import Foundation
#if canImport(ActivityKit)
import ActivityKit

public struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let costCents: Int64
        public let distanceMeters: Double
        public let totalPeople: Int
        public let indicativeShareCents: Int64
        public let phase: String
        public let lastUpdatedAt: Date

        public init(costCents: Int64, distanceMeters: Double, totalPeople: Int, indicativeShareCents: Int64, phase: String, lastUpdatedAt: Date) {
            self.costCents = costCents; self.distanceMeters = distanceMeters; self.totalPeople = totalPeople
            self.indicativeShareCents = indicativeShareCents; self.phase = phase; self.lastUpdatedAt = lastUpdatedAt
        }
    }

    public let tripID: String
    public let vehicleName: String
    public let currency: String
    public let startedAt: Date

    public init(tripID: String, vehicleName: String, currency: String = "EUR", startedAt: Date) {
        self.tripID = tripID; self.vehicleName = vehicleName; self.currency = currency; self.startedAt = startedAt
    }
}
#endif
