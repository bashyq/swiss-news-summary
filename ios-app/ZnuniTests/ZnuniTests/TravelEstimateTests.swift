import XCTest
@testable import Znuni

/// Regression tests for TravelEstimate — calculates travel mode and time between venues.
/// Tests start RED (wrapped in #if false) until TravelEstimate is implemented.
final class TravelEstimateTests: XCTestCase {

    // MARK: - Zurich Coordinates

    // Zurich HB (main station)
    private let hbLat = 47.3769
    private let hbLon = 8.5417

    // ~400m south of HB (Bahnhofstrasse area)
    private let nearLat = 47.3733
    private let nearLon = 8.5395

    // Zoo Zurich (~4.5km from HB)
    private let zooLat = 47.3849
    private let zooLon = 8.5743

    // ~2km from HB (ETH area)
    private let ethLat = 47.3763
    private let ethLon = 8.5484

    // MARK: - Mode Selection

    #if false
    func test_under1km_isWalking() {
        let estimate = TravelEstimate.between(
            fromLat: hbLat, fromLon: hbLon,
            toLat: nearLat, toLon: nearLon
        )
        XCTAssertEqual(estimate.mode, .walking)
    }

    func test_1to3km_isTransit() {
        let estimate = TravelEstimate.between(
            fromLat: hbLat, fromLon: hbLon,
            toLat: ethLat, toLon: ethLon
        )
        XCTAssertEqual(estimate.mode, .transit)
    }

    func test_over3km_isTransit() {
        let estimate = TravelEstimate.between(
            fromLat: hbLat, fromLon: hbLon,
            toLat: zooLat, toLon: zooLon
        )
        XCTAssertEqual(estimate.mode, .transit)
    }
    #endif

    // MARK: - Time Estimates

    #if false
    func test_walkingTime_isReasonable() {
        let estimate = TravelEstimate.between(
            fromLat: hbLat, fromLon: hbLon,
            toLat: nearLat, toLon: nearLon
        )
        // 400m walk should be 1-10 minutes
        XCTAssertGreaterThanOrEqual(estimate.minutes, 1)
        XCTAssertLessThanOrEqual(estimate.minutes, 10)
    }

    func test_transitTime_includes5minWait() {
        let estimate = TravelEstimate.between(
            fromLat: hbLat, fromLon: hbLon,
            toLat: ethLat, toLon: ethLon
        )
        // ~2km transit should be at least 10 min (travel + 5 min wait)
        XCTAssertGreaterThanOrEqual(estimate.minutes, 10)
    }
    #endif

    // MARK: - Edge Cases

    #if false
    func test_nilCoordinates_returnsDefault() {
        let estimate = TravelEstimate.between(
            fromLat: nil, fromLon: nil,
            toLat: nil, toLon: nil
        )
        // Should return a sensible default, not crash
        XCTAssertGreaterThan(estimate.minutes, 0)
        XCTAssertEqual(estimate.mode, .walking)
    }
    #endif
}
