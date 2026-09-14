import Foundation

public struct StationaryDetector: Sendable {
    public let speedThreshold: Double
    public let durationThreshold: TimeInterval
    private var stationarySince: Date?

    public init(speedThreshold: Double = 0.8, durationThreshold: TimeInterval = 180) {
        self.speedThreshold = speedThreshold; self.durationThreshold = durationThreshold
    }

    public mutating func observe(_ fix: LocationFix) -> Bool {
        guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= 65 else { return false }
        let speed = max(0, fix.speedMetersPerSecond ?? 0)
        if speed > speedThreshold { stationarySince = nil; return false }
        if stationarySince == nil { stationarySince = fix.timestamp }
        return fix.timestamp.timeIntervalSince(stationarySince!) >= durationThreshold
    }

    public mutating func reset() { stationarySince = nil }
}
