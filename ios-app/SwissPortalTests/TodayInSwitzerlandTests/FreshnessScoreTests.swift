import XCTest
@testable import SwissPortal

final class FreshnessScoreTests: XCTestCase {

    // ── Mock visit store ──────────────────────────────────────

    class MockVisitStore: VenueVisitStore {
        var mockVisits: [String: Int] = [:]  // venueId → days since last visit
        var mockCounts: [String: Int] = [:]  // venueId → visits in last 30 days

        override func daysSinceLastVisit(for venueId: String) -> Int? {
            mockVisits[venueId]
        }
        override func visitCount(for venueId: String, inLast days: Int) -> Int {
            mockCounts[venueId] ?? 0
        }
    }

    // ── Mock weather ──────────────────────────────────────────

    /// Create a Weather value with the given temperature and optional rain codes.
    /// Uses WMO weather codes: 0 = clear, 2 = partly cloudy, 61 = light rain, 65 = heavy rain.
    private func weather(temp: Double, heavyRain: Bool = false, lightRain: Bool = false) -> Weather {
        let code: Int
        if heavyRain {
            code = 65  // Heavy rain
        } else if lightRain {
            code = 61  // Light rain
        } else {
            code = 2   // Partly cloudy
        }
        return Weather(
            temperature: temp,
            description: heavyRain ? "Heavy rain" : (lightRain ? "Light rain" : "Partly cloudy"),
            weatherCode: code,
            windSpeed: 5,
            hourly: nil
        )
    }

    // ── Mock activity ─────────────────────────────────────────

    private func activity(
        id: String = "test-activity",
        indoor: Bool = true,
        recurring: String? = nil,
        suggestibility: String? = nil,
        availableMonths: [Int]? = nil
    ) -> Activity {
        Activity(
            id: id, name: "Test Activity", nameDE: "Test",
            description: "A test activity", descriptionDE: "Eine Test-Aktivität",
            indoor: indoor, ageRange: "2-5", duration: "2 hours",
            price: "CHF 10", priceDE: "CHF 10", url: nil,
            lat: 47.38, lon: 8.54, category: "museum",
            minAge: 2, maxAge: 5, season: nil, free: nil,
            recurring: recurring, stayHome: nil,
            availableMonths: availableMonths,
            subcategory: nil, materials: nil, materialsDE: nil,
            addedDate: nil, suggestibility: suggestibility
        )
    }

    // ── Mock restaurant ───────────────────────────────────────

    private func restaurant(
        id: String = "test-restaurant",
        openForLunch: Bool = true,
        openForDinner: Bool = true
    ) -> LunchSpot {
        LunchSpot(
            id: id, name: "Test Restaurant",
            lat: 47.38, lon: 8.54,
            cuisine: "italian", cuisineCategory: "italian",
            wheelchair: nil, outdoorSeating: nil, takeaway: nil,
            openingHours: "Mo-Su 11:00-23:00",
            openForLunch: openForLunch,
            openForDinner: openForDinner,
            kidFriendly: true,
            vegetarian: nil, vegan: nil,
            phone: nil, website: nil,
            amenity: "restaurant",
            rating: 4.5, ratingCount: 200,
            permanentlyClosed: nil
        )
    }

    private let today = Date()

    // ─────────────────────────────────────────────
    // Test 1: Visited 3 days ago → ineligible (14-day window)
    // ─────────────────────────────────────────────
    func test_visitedRecently_isIneligible() {
        let store = MockVisitStore()
        store.mockVisits["zoo-zurich"] = 3  // visited 3 days ago

        let score = FreshnessScorer.scoreActivity(
            activity(id: "zoo-zurich"),
            visitStore: store,
            weather: weather(temp: 15),
            date: today
        )

        XCTAssertFalse(score.isEligible, "Venue visited 3 days ago should be ineligible (14-day window)")
    }

    // ─────────────────────────────────────────────
    // Test 2: Activity with recurring field → ineligible (feed only)
    // ─────────────────────────────────────────────
    func test_recurringActivity_isIneligible() {
        let store = MockVisitStore()

        let score = FreshnessScorer.scoreActivity(
            activity(id: "farmers-market", recurring: "Tue & Fri 6:00–11:00"),
            visitStore: store,
            weather: weather(temp: 15),
            date: today
        )

        XCTAssertFalse(score.isEligible, "Recurring activity should never enter the planning pool")
    }

    // ─────────────────────────────────────────────
    // Test 3: Outdoor venue, temp 5°C → eligible but low weather score
    // ─────────────────────────────────────────────
    func test_outdoorVenue_coldWeather_lowWeatherScore() {
        let store = MockVisitStore()  // no visits

        let score = FreshnessScorer.scoreActivity(
            activity(id: "rieterpark", indoor: false),
            visitStore: store,
            weather: weather(temp: 5),
            date: today
        )

        XCTAssertTrue(score.isEligible, "Should still be eligible — just lower scored")
        // Composite will be dragged down by weather — shouldn't dominate the pool
        let indoorScore = FreshnessScorer.scoreActivity(
            activity(id: "museum-rietberg", indoor: true),
            visitStore: store,
            weather: weather(temp: 5),
            date: today
        )
        XCTAssertGreaterThan(
            indoorScore.compositeScore,
            score.compositeScore,
            "Indoor venue should score higher than outdoor on a cold day"
        )
    }

    // ─────────────────────────────────────────────
    // Test 4: suggestibility = "feedOnly" → ineligible
    // ─────────────────────────────────────────────
    func test_feedOnlySuggestibility_isIneligible() {
        let store = MockVisitStore()

        let score = FreshnessScorer.scoreActivity(
            activity(id: "christmas-market", suggestibility: "feedOnly"),
            visitStore: store,
            weather: weather(temp: 2),
            date: today
        )

        XCTAssertFalse(score.isEligible, "feedOnly venues should never appear in planning pool")
    }

    // ─────────────────────────────────────────────
    // Test 5: Never visited → freshness score = 1.0
    // ─────────────────────────────────────────────
    func test_neverVisited_maxFreshnessScore() {
        let store = MockVisitStore()  // no visits recorded

        let score = FreshnessScorer.scoreActivity(
            activity(id: "new-venue"),
            visitStore: store,
            weather: weather(temp: 15),
            date: today
        )

        XCTAssertTrue(score.isEligible)
        // Freshness component should be 1.0 — verify composite is high
        XCTAssertGreaterThan(score.compositeScore, 0.7,
            "Never-visited venue on good weather day should score > 0.7")
    }

    // ─────────────────────────────────────────────
    // Test 6: Restaurant — not open for lunch → ineligible for lunch slot
    // ─────────────────────────────────────────────
    func test_restaurant_notOpenForLunch_ineligibleForLunchSlot() {
        let store = MockVisitStore()

        let score = FreshnessScorer.scoreRestaurant(
            restaurant(id: "dinner-only", openForLunch: false, openForDinner: true),
            slotType: .lunch,
            visitStore: store,
            date: today
        )

        XCTAssertFalse(score.isEligible, "Dinner-only restaurant should be ineligible for lunch slot")
    }

    // ─────────────────────────────────────────────
    // Test 7: Restaurant — not open for dinner → ineligible for dinner slot
    // ─────────────────────────────────────────────
    func test_restaurant_notOpenForDinner_ineligibleForDinnerSlot() {
        let store = MockVisitStore()

        let score = FreshnessScorer.scoreRestaurant(
            restaurant(id: "lunch-only", openForLunch: true, openForDinner: false),
            slotType: .dinner,
            visitStore: store,
            date: today
        )

        XCTAssertFalse(score.isEligible, "Lunch-only restaurant should be ineligible for dinner slot")
    }

    // ─────────────────────────────────────────────
    // Test 8: Seasonal activity — wrong month → ineligible
    // ─────────────────────────────────────────────
    func test_seasonalActivity_wrongMonth_isIneligible() {
        let store = MockVisitStore()

        // Summer-only activity [6,7,8], test in March (month 3)
        var components = Calendar.current.dateComponents([.year], from: Date())
        components.month = 3
        components.day = 15
        let marchDate = Calendar.current.date(from: components)!

        let score = FreshnessScorer.scoreActivity(
            activity(id: "freibad-zurich", indoor: false,
                     suggestibility: "seasonal", availableMonths: [6, 7, 8]),
            visitStore: store,
            weather: weather(temp: 12),
            date: marchDate
        )

        XCTAssertFalse(score.isEligible, "Summer-only venue should be ineligible in March")
    }

    // ─────────────────────────────────────────────
    // Test 9: Over-rotation penalty — visited 3 times in 30 days
    // ─────────────────────────────────────────────
    func test_overRotation_reducesCompositeScore() {
        let storeFrequent = MockVisitStore()
        storeFrequent.mockVisits["popular-venue"] = 20  // visited 20 days ago (eligible)
        storeFrequent.mockCounts["popular-venue"] = 3   // but 3 times in last 30 days

        let storeFresh = MockVisitStore()
        // No visits at all

        let frequentScore = FreshnessScorer.scoreActivity(
            activity(id: "popular-venue"),
            visitStore: storeFrequent,
            weather: weather(temp: 15),
            date: today
        )
        let freshScore = FreshnessScorer.scoreActivity(
            activity(id: "popular-venue"),
            visitStore: storeFresh,
            weather: weather(temp: 15),
            date: today
        )

        XCTAssertTrue(frequentScore.isEligible)
        XCTAssertGreaterThan(freshScore.compositeScore, frequentScore.compositeScore,
            "Never-visited should score higher than frequently-visited")
    }
}
