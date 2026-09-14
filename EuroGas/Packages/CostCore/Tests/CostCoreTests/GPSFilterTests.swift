import XCTest
@testable import CostCore

final class GPSFilterTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testAcceptedAnchorAndSegmentAccumulateDistance() {
        var filter = GPSFilter()
        XCTAssertEqual(filter.process(fix(latitude: 40, longitude: -3, seconds: 0)), .anchor)
        let result = filter.process(fix(latitude: 40.0001, longitude: -3, seconds: 2))
        guard case let .normal(distance) = result else { return XCTFail("Expected normal segment") }
        XCTAssertGreaterThan(distance, 10)
        XCTAssertEqual(filter.snapshot.acceptedDistanceMeters, distance, accuracy: 0.001)
    }

    func testRejectedJitterDoesNotMoveAnchor() {
        var filter = GPSFilter()
        _ = filter.process(fix(latitude: 40, longitude: -3, seconds: 0))
        XCTAssertEqual(filter.process(fix(latitude: 40.000001, longitude: -3, seconds: 1)), .rejected(.jitter))
        XCTAssertEqual(filter.lastAcceptedFix?.latitude, 40)
    }

    func testLongGapIsUnmeasuredAndNotInvented() {
        var filter = GPSFilter()
        _ = filter.process(fix(latitude: 40, longitude: -3, seconds: 0))
        XCTAssertEqual(filter.process(fix(latitude: 40.01, longitude: -3, seconds: 120)), .unmeasuredInterval)
        XCTAssertEqual(filter.snapshot.acceptedDistanceMeters, 0)
        XCTAssertEqual(filter.snapshot.unmeasuredIntervalCount, 1)
    }

    func testStationaryDetectorTriggersAfterThreeMinutesOfValidFixes() {
        var detector = StationaryDetector()
        XCTAssertFalse(detector.observe(LocationFix(latitude: 40, longitude: -3, horizontalAccuracy: 5, speedMetersPerSecond: 0.1, timestamp: start)))
        XCTAssertTrue(detector.observe(LocationFix(latitude: 40, longitude: -3, horizontalAccuracy: 5, speedMetersPerSecond: 0.1, timestamp: start.addingTimeInterval(180))))
        detector.reset()
        XCTAssertFalse(detector.observe(LocationFix(latitude: 40, longitude: -3, horizontalAccuracy: 5, speedMetersPerSecond: 2, timestamp: start.addingTimeInterval(181))))
    }

    private func fix(latitude: Double, longitude: Double, seconds: TimeInterval) -> LocationFix {
        LocationFix(latitude: latitude, longitude: longitude, horizontalAccuracy: 5, timestamp: start.addingTimeInterval(seconds))
    }
}
