import Foundation
import CoreLocation

// MARK: - Venue Score

/// Result of scoring a single venue. `isEligible == false` means hard-excluded
/// from the pool — never shown to Claude.
struct VenueScore {
    let venueId: String
    let isEligible: Bool
    let compositeScore: Double      // 0.0–1.0, only meaningful when isEligible
}

// MARK: - Freshness Scorer

/// Deterministic venue scoring based on visit history, weather, and variety.
/// Called before every AgendaComposer invocation to build a pre-qualified pool.
struct FreshnessScorer {

    // MARK: - Score Activity

    static func scoreActivity(
        _ activity: Activity,
        visitStore: VenueVisitStore,
        weather: Weather,
        date: Date,
        gapMidpoint: Date? = nil
    ) -> VenueScore {

        // ── Hard exclusions ──────────────────────────────────

        // 1. Feed-only: recurring and stayhome never enter planning pool
        if activity.isFeedOnly { return ineligible(activity.id) }

        // 2. Seasonal: only suggest in available months
        if let months = activity.availableMonths {
            let month = Calendar.current.component(.month, from: date)
            if !months.contains(month) { return ineligible(activity.id) }
        }

        // 3. Visit recency
        let exclusion = activity.exclusionDays
        if let days = visitStore.daysSinceLastVisit(for: activity.id), days < exclusion {
            return ineligible(activity.id)
        }

        // 4. Opening hours: if we know when the gap is, check if venue is open at that time
        if let checkTime = gapMidpoint {
            let status = OpeningHoursParser.status(from: activity.openingHours, at: checkTime)
            if status == .closed { return ineligible(activity.id) }
        }

        // ── Soft scoring ──────────────────────────────────────

        let freshness = freshnessScore(
            venueId: activity.id, visitStore: visitStore, exclusionDays: exclusion)

        let weatherScore: Double
        if activity.indoor {
            weatherScore = 1.0
        } else {
            weatherScore = outdoorWeatherScore(weather)
        }

        let seasonal = activity.availableMonths == nil ? 0.85 : 1.0

        let recentCount = visitStore.visitCount(for: activity.id, inLast: 30)
        let variety = max(0.0, 1.0 - Double(recentCount) * 0.25)

        let composite = (freshness * 0.35) + (weatherScore * 0.30)
                      + (seasonal * 0.20) + (variety * 0.15)

        return VenueScore(venueId: activity.id, isEligible: true, compositeScore: composite)
    }

    // MARK: - Score Restaurant

    static func scoreRestaurant(
        _ restaurant: LunchSpot,
        slotType: SuggestionType,
        visitStore: VenueVisitStore,
        date: Date,
        gapMidpoint: Date? = nil
    ) -> VenueScore {

        // 1. Minimum quality threshold — skip low-rated and low-review restaurants
        if let rating = restaurant.rating, rating < 4.0 {
            return ineligible(restaurant.id)
        }
        if let count = restaurant.ratingCount, count < 10 {
            return ineligible(restaurant.id)
        }

        // 2. Slot type eligibility
        switch slotType {
        case .lunch:
            if restaurant.openForLunch == false { return ineligible(restaurant.id) }
        case .dinner:
            if restaurant.openForDinner == false { return ineligible(restaurant.id) }
        default:
            return ineligible(restaurant.id)
        }

        // 2. Opening hours: if Booleans are nil but we have OSM hours string, parse it
        if let checkTime = gapMidpoint {
            let boolKnown = (slotType == .lunch && restaurant.openForLunch != nil)
                         || (slotType == .dinner && restaurant.openForDinner != nil)
            if !boolKnown {
                let status = OpeningHoursParser.status(from: restaurant.openingHours, at: checkTime)
                if status == .closed { return ineligible(restaurant.id) }
            }
        }

        // 3. Visit recency (restaurants: 14-day default)
        let exclusionDays = 14
        if let days = visitStore.daysSinceLastVisit(for: restaurant.id), days < exclusionDays {
            return ineligible(restaurant.id)
        }

        let freshness = freshnessScore(
            venueId: restaurant.id, visitStore: visitStore, exclusionDays: exclusionDays)
        let recentCount = visitStore.visitCount(for: restaurant.id, inLast: 30)
        let variety = max(0.0, 1.0 - Double(recentCount) * 0.25)
        let composite = (freshness * 0.50) + (variety * 0.50)

        return VenueScore(venueId: restaurant.id, isEligible: true, compositeScore: composite)
    }

    // MARK: - Build Scored Pool

    /// Pre-filter and rank venues for the agenda composer prompt.
    static func buildScoredPool(
        activities: [Activity],
        restaurants: [LunchSpot],
        weather: Weather,
        date: Date,
        fillableGaps: [FreeGap],
        visitStore: VenueVisitStore
    ) -> (activities: [Activity], lunches: [LunchSpot], dinners: [LunchSpot]) {

        let needsDinner = fillableGaps.contains { $0.suggestedType == .dinner }
        let needsLunch = fillableGaps.contains { $0.suggestedType == .lunch }

        // Compute gap midpoints for opening hours checks
        let activityGap = fillableGaps.first {
            $0.suggestedType == .morningActivity || $0.suggestedType == .afternoonActivity || $0.suggestedType == .quickActivity
        }
        let lunchGap = fillableGaps.first { $0.suggestedType == .lunch }
        let dinnerGap = fillableGaps.first { $0.suggestedType == .dinner }

        let activityMidpoint = activityGap.map { midpoint(of: $0) }
        let lunchMidpoint = lunchGap.map { midpoint(of: $0) }
        let dinnerMidpoint = dinnerGap.map { midpoint(of: $0) }

        // Find anchor locations adjacent to activity/lunch/dinner gaps for proximity bias
        let activityAnchorLocation = anchorLocation(for: activityGap)
        let lunchAnchorLocation = anchorLocation(for: lunchGap)
        let dinnerAnchorLocation = anchorLocation(for: dinnerGap)

        var scoredActivities = activities
            .map { ($0, scoreActivity($0, visitStore: visitStore, weather: weather, date: date, gapMidpoint: activityMidpoint)) }
            .filter { $0.1.isEligible }

        // Apply proximity bias for activities near anchor locations
        if let anchorLoc = activityAnchorLocation {
            scoredActivities = applyProximityBias(
                scored: scoredActivities,
                anchorLocation: anchorLoc,
                coordinateExtractor: { act in
                    guard let lat = act.lat, let lon = act.lon else { return nil }
                    return CLLocation(latitude: lat, longitude: lon)
                }
            )
        }

        let topActivities = scoredActivities
            .shuffled()  // Break ties so rebuilds produce different selections
            .sorted { $0.1.compositeScore > $1.1.compositeScore }
            .prefix(15)
            .map { $0.0 }

        var scoredLunchPairs: [(LunchSpot, VenueScore)] = needsLunch ? restaurants
            .map { ($0, scoreRestaurant($0, slotType: .lunch, visitStore: visitStore, date: date, gapMidpoint: lunchMidpoint)) }
            .filter { $0.1.isEligible } : []

        if let anchorLoc = lunchAnchorLocation, needsLunch {
            scoredLunchPairs = applyProximityBias(
                scored: scoredLunchPairs,
                anchorLocation: anchorLoc,
                coordinateExtractor: { spot in
                    CLLocation(latitude: spot.lat, longitude: spot.lon)
                }
            )
        }

        let topLunches = scoredLunchPairs
            .shuffled()  // Break ties — without this, same-score venues always appear in API order
            .sorted { $0.1.compositeScore > $1.1.compositeScore }
            .prefix(10)
            .map { $0.0 }

        var scoredDinnerPairs: [(LunchSpot, VenueScore)] = needsDinner ? restaurants
            .map { ($0, scoreRestaurant($0, slotType: .dinner, visitStore: visitStore, date: date, gapMidpoint: dinnerMidpoint)) }
            .filter { $0.1.isEligible } : []

        if let anchorLoc = dinnerAnchorLocation, needsDinner {
            scoredDinnerPairs = applyProximityBias(
                scored: scoredDinnerPairs,
                anchorLocation: anchorLoc,
                coordinateExtractor: { spot in
                    CLLocation(latitude: spot.lat, longitude: spot.lon)
                }
            )
        }

        let topDinners = scoredDinnerPairs
            .shuffled()
            .sorted { $0.1.compositeScore > $1.1.compositeScore }
            .prefix(10)
            .map { $0.0 }

        return (Array(topActivities), Array(topLunches), Array(topDinners))
    }

    // MARK: - Proximity Bias

    /// Extract the location of the nearest anchor adjacent to a gap.
    private static func anchorLocation(for gap: FreeGap?) -> CLLocation? {
        guard let gap else { return nil }
        // Prefer the preceding anchor (venue after the anchor should be nearby)
        if let anchor = gap.precedingAnchor, let lat = anchor.lat, let lon = anchor.lon {
            return CLLocation(latitude: lat, longitude: lon)
        }
        if let anchor = gap.followingAnchor, let lat = anchor.lat, let lon = anchor.lon {
            return CLLocation(latitude: lat, longitude: lon)
        }
        return nil
    }

    /// Boost scores of venues within ~3 km of a nearby anchor location.
    /// Venues within 1 km get a +0.2 boost, 1-3 km get +0.1, beyond 3 km get no boost.
    static func applyProximityBias<T>(
        scored: [(T, VenueScore)],
        anchorLocation: CLLocation,
        coordinateExtractor: (T) -> CLLocation?
    ) -> [(T, VenueScore)] {
        scored.map { item, score in
            guard let venueLoc = coordinateExtractor(item) else { return (item, score) }
            let distanceKm = anchorLocation.distance(from: venueLoc) / 1000.0
            let boost: Double
            if distanceKm <= 1.0 {
                boost = 0.2
            } else if distanceKm <= 3.0 {
                boost = 0.1
            } else {
                boost = 0.0
            }
            let adjusted = VenueScore(
                venueId: score.venueId,
                isEligible: score.isEligible,
                compositeScore: min(1.0, score.compositeScore + boost)
            )
            return (item, adjusted)
        }
    }

    // MARK: - Helpers

    private static func freshnessScore(
        venueId: String, visitStore: VenueVisitStore, exclusionDays: Int
    ) -> Double {
        guard let days = visitStore.daysSinceLastVisit(for: venueId) else { return 1.0 }
        return min(1.0, Double(days) / Double(exclusionDays * 2))
    }

    private static func outdoorWeatherScore(_ weather: Weather) -> Double {
        let heavyRainCodes = [63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
        let lightRainCodes = [51, 53, 55, 56, 57, 61]

        if weather.temperature < 8 || heavyRainCodes.contains(weather.weatherCode) { return 0.1 }
        if weather.temperature < 14 || lightRainCodes.contains(weather.weatherCode) { return 0.5 }
        return 1.0
    }

    /// Midpoint of a gap's effective time window — used for opening hours checks.
    private static func midpoint(of gap: FreeGap) -> Date {
        let interval = gap.gapEnd.timeIntervalSince(gap.effectiveStart)
        return gap.effectiveStart.addingTimeInterval(interval / 2)
    }

    private static func ineligible(_ id: String) -> VenueScore {
        VenueScore(venueId: id, isEligible: false, compositeScore: 0)
    }
}
