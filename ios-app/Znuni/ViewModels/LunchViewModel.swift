import Foundation
import CoreLocation

/// ViewModel for the Lunch view — manages fetching, filtering, and the "Surprise me!" feature
/// for restaurant recommendations with map and list display.
@Observable
final class LunchViewModel {

    // MARK: - Published State

    /// The full lunch response from the API (spots list, city info)
    var lunchData: LunchResponse?

    /// Active toggle filters (multi-select, combine freely)
    var activeToggles: Set<LunchToggle> = [] {
        didSet { showingAll = false }
    }

    /// Current cuisine filter (single-select)
    var cuisineFilter: CuisineFilter = .all {
        didSet { showingAll = false }
    }

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    /// Whether the map strip is shown (true = map + list, false = list only)
    var showMap: Bool = false

    /// Maximum number of spots to display in the list (all remain in memory for map/filtering)
    var displayLimit: Int = 50

    /// Whether the user has tapped "Show all" to bypass the display limit
    var showingAll: Bool = false

    /// Current sort order — persisted across sessions. Default: nearest first.
    var sortOrder: LunchSort = {
        if let raw = UserDefaults.standard.string(forKey: "lunchSortOrder"),
           let saved = LunchSort(rawValue: raw) {
            return saved
        }
        return .nearest
    }() {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: "lunchSortOrder")
        }
    }

    // MARK: - Filtering

    /// Returns lunch spots filtered by all active toggles and cuisine filter.
    /// Toggles stack (AND logic): e.g. Near Me + Open + Italian = open Italian restaurants within 2km.
    ///
    /// - Parameters:
    ///   - savedIDs: Set of saved lunch spot IDs from app state.
    ///   - userLocation: User's current location for "Near Me" filtering.
    /// - Returns: Filtered array of lunch spots.
    func filteredSpots(savedIDs: Set<String>, userLocation: CLLocation? = nil) -> [LunchSpot] {
        guard var spots = lunchData?.spots else { return [] }

        // Apply toggle filters (AND logic)
        if activeToggles.contains(.nearMe), let location = userLocation {
            spots = spots.filter { $0.distance(from: location) <= 2000 }
        }
        if activeToggles.contains(.open) {
            spots = spots.filter { $0.openForLunch == true }
        }
        if activeToggles.contains(.terrace) {
            spots = spots.filter { $0.outdoorSeating == true }
        }
        if activeToggles.contains(.saved) {
            spots = spots.filter { savedIDs.contains($0.id) }
        }

        // Apply cuisine filter
        if let cuisineValue = cuisineFilter.apiValue {
            spots = spots.filter { $0.cuisineCategory?.caseInsensitiveCompare(cuisineValue) == .orderedSame }
        }

        return spots
    }

    /// Returns a limited slice of spots for display. All spots remain available for map/filtering.
    func displaySpots(from spots: [LunchSpot]) -> [LunchSpot] {
        showingAll ? spots : Array(spots.prefix(displayLimit))
    }

    // MARK: - Surprise Me

    /// Pick a random lunch spot from the currently filtered results.
    ///
    /// - Parameter savedIDs: Set of saved lunch spot IDs from app state.
    /// - Returns: A random lunch spot matching the current filter, or `nil` if none available.
    func surpriseMe(savedIDs: Set<String>) -> LunchSpot? {
        let spots = filteredSpots(savedIDs: savedIDs)
        return spots.randomElement()
    }

    // MARK: - Loading

    /// Load lunch spots for the given city and language.
    ///
    /// Strategy: show cached data immediately (if available), then fetch fresh data in the background.
    ///
    /// - Parameters:
    ///   - city: The selected city.
    ///   - language: The display language.
    @MainActor
    func loadLunch(city: City, language: AppLanguage) async {
        let cacheKey = CacheKey.lunch(city: city)

        // 1. Show cached data immediately
        let cached: LunchResponse? = await CacheManager.shared.get(
            LunchResponse.self,
            key: cacheKey,
            ttl: .lunch
        )
        if let cached {
            self.lunchData = cached
        }

        // 2. Fetch fresh data from the API
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchLunch(
                city: city,
                language: language
            )

            self.lunchData = response

            // Cache the fresh response
            await CacheManager.shared.set(response, key: cacheKey)

            self.error = nil
        } catch {
            // Only set error if we have no cached data to show
            if self.lunchData == nil {
                // Try stale cache before showing error
                let stale: LunchResponse? = await CacheManager.shared.getStale(LunchResponse.self, key: cacheKey)
                if let stale {
                    self.lunchData = stale
                } else {
                    self.error = error.localizedDescription
                }
            }
        }

        isLoading = false
    }
}
