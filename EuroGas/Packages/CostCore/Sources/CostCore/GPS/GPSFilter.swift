import Foundation

public struct GPSFilter: Sendable {
    public struct Configuration: Equatable, Sendable {
        public let maximumHorizontalAccuracy: Double
        public let maximumImplicitSpeed: Double
        public let maximumEstimatedGapSeconds: TimeInterval
        public let maximumEstimatedGapMeters: Double
        public let jitterFloorMeters: Double

        public init(maximumHorizontalAccuracy: Double = 65, maximumImplicitSpeed: Double = 62, maximumEstimatedGapSeconds: TimeInterval = 90, maximumEstimatedGapMeters: Double = 3_000, jitterFloorMeters: Double = 5) {
            self.maximumHorizontalAccuracy = maximumHorizontalAccuracy
            self.maximumImplicitSpeed = maximumImplicitSpeed
            self.maximumEstimatedGapSeconds = maximumEstimatedGapSeconds
            self.maximumEstimatedGapMeters = maximumEstimatedGapMeters
            self.jitterFloorMeters = jitterFloorMeters
        }
    }

    public private(set) var snapshot: GPSAccumulatorSnapshot
    public private(set) var lastAcceptedFix: LocationFix?
    private let configuration: Configuration
    private var requiresFreshAnchor: Bool

    public init(configuration: Configuration = .init(), snapshot: GPSAccumulatorSnapshot = .init(), lastAcceptedFix: LocationFix? = nil, requiresFreshAnchor: Bool = false) {
        self.configuration = configuration
        self.snapshot = snapshot
        self.lastAcceptedFix = lastAcceptedFix
        self.requiresFreshAnchor = requiresFreshAnchor
    }

    public mutating func requireFreshAnchor() {
        requiresFreshAnchor = true
        lastAcceptedFix = nil
        snapshot.unmeasuredIntervalCount += 1
    }

    public mutating func process(_ fix: LocationFix) -> GPSSegmentClassification {
        guard fix.latitude.isFinite, fix.longitude.isFinite,
              (-90...90).contains(fix.latitude), (-180...180).contains(fix.longitude) else {
            return reject(.invalidCoordinate)
        }
        guard fix.horizontalAccuracy.isFinite, fix.horizontalAccuracy >= 0,
              fix.horizontalAccuracy <= configuration.maximumHorizontalAccuracy else {
            return reject(.inaccurate)
        }
        guard let previous = lastAcceptedFix else {
            lastAcceptedFix = fix
            requiresFreshAnchor = false
            return .anchor
        }
        let elapsed = fix.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else { return reject(.nonIncreasingTimestamp) }
        let distance = Self.distance(from: previous, to: fix)
        let implicitSpeed = distance / elapsed
        guard implicitSpeed <= configuration.maximumImplicitSpeed else {
            return reject(.implausibleSpeed)
        }
        if requiresFreshAnchor || elapsed > configuration.maximumEstimatedGapSeconds || distance > configuration.maximumEstimatedGapMeters {
            lastAcceptedFix = fix
            requiresFreshAnchor = false
            snapshot.unmeasuredIntervalCount += 1
            return .unmeasuredInterval
        }
        let noiseThreshold = max(configuration.jitterFloorMeters, min(previous.horizontalAccuracy, fix.horizontalAccuracy) * 0.25)
        guard distance >= noiseThreshold else { return reject(.jitter) }
        lastAcceptedFix = fix
        snapshot.acceptedDistanceMeters += distance
        if elapsed > 20 {
            snapshot.estimatedGapDistanceMeters += distance
            return .estimatedGap(distanceMeters: distance)
        }
        return .normal(distanceMeters: distance)
    }

    private mutating func reject(_ reason: GPSRejectionReason) -> GPSSegmentClassification {
        snapshot.rejectedFixCount += 1
        return .rejected(reason)
    }

    private static func distance(from a: LocationFix, to b: LocationFix) -> Double {
        let radius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return radius * 2 * atan2(sqrt(h), sqrt(1 - h))
    }
}
