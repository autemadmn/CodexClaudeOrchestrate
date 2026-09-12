import Foundation

public struct LocationFix: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let horizontalAccuracy: Double
    public let speedMetersPerSecond: Double?
    public let timestamp: Date

    public init(latitude: Double, longitude: Double, horizontalAccuracy: Double, speedMetersPerSecond: Double? = nil, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speedMetersPerSecond = speedMetersPerSecond
        self.timestamp = timestamp
    }
}

public enum GPSRejectionReason: String, Codable, Equatable, Sendable {
    case invalidCoordinate
    case inaccurate
    case nonIncreasingTimestamp
    case implausibleSpeed
    case jitter
}

public enum GPSSegmentClassification: Codable, Equatable, Sendable {
    case anchor
    case normal(distanceMeters: Double)
    case estimatedGap(distanceMeters: Double)
    case unmeasuredInterval
    case rejected(GPSRejectionReason)
}

public struct GPSAccumulatorSnapshot: Codable, Equatable, Sendable {
    public var acceptedDistanceMeters: Double
    public var estimatedGapDistanceMeters: Double
    public var rejectedFixCount: Int
    public var unmeasuredIntervalCount: Int

    public init(acceptedDistanceMeters: Double = 0, estimatedGapDistanceMeters: Double = 0, rejectedFixCount: Int = 0, unmeasuredIntervalCount: Int = 0) {
        self.acceptedDistanceMeters = acceptedDistanceMeters
        self.estimatedGapDistanceMeters = estimatedGapDistanceMeters
        self.rejectedFixCount = rejectedFixCount
        self.unmeasuredIntervalCount = unmeasuredIntervalCount
    }
}
