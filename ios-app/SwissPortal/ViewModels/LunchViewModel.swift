import Foundation

/// ViewModel for the Lunch view — manages fetching, filtering, and the "Surprise me!" feature
/// for restaurant recommendations with map and list display.
@Observable
final class LunchViewModel {

    // MARK: - Published State

    /// The full lunch response from the API (spots list, city info)
    var lunchData: LunchResponse?

    /// Current filter for lunch spots
    var filter: LunchFilter = .all

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    /// Whether the map strip is shown (true = map + list, false = list only)
    var showMap: Bool = true

    // MARK: - Filtering

    /// Returns lunch spots filtered by the current `filter`.
    ///
    /// The `savedIDs` parameter is passed in from `AppState.savedLunchIDs` since
    /// the saved set is owned by the app-level state, not this view model.
    ///
    /// - Parameter savedIDs: Set of saved lunch spot IDs from app state.
    /// - Returns: Filtered array of lunch spots.
    func filteredSpots(savedIDs: Set<String>) -> [LunchSpot] {
        guard let spots = lunchData?.spots else { return [] }

        switch filter {
        case .all:
            return spots
        case .saved:
            return spots.filter { savedIDs.contains($0.id) }
        case .open:
            return spots.filter { $0.openForLunch == true }
        case .outdoor:
            return spots.filter { $0.outdoorSeating == true }
        case .vegetarian:
            return spots.filter { $0.vegetarian == true }
        }
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
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}
