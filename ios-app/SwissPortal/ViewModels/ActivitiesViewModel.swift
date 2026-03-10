import Foundation

/// ViewModel for the Activities view — manages fetching, filtering, and the "Surprise me!" feature.
@Observable
final class ActivitiesViewModel {

    // MARK: - Published State

    /// The full activities response from the API (activities list, city events, weather)
    var activitiesData: ActivitiesResponse?

    /// Current activity filter (all, indoor, outdoor, free, etc.)
    var filter: ActivityFilter = .all

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    /// Whether the map view is shown (vs. list view)
    var showMap: Bool = false

    // MARK: - Filtering

    /// Returns activities filtered by the current `filter` and `ageFilter`.
    ///
    /// The `savedIDs` parameter is passed in from `AppState.savedActivityIDs` since
    /// the saved set is owned by the app-level state, not this view model.
    func filteredActivities(savedIDs: Set<String>) -> [Activity] {
        guard let activities = activitiesData?.activities else { return [] }

        // Apply category filter first
        let categoryFiltered: [Activity]
        switch filter {
        case .all:
            // Sort featured activities to the top
            categoryFiltered = activities
                .filter { !$0.isStayHome }
                .sorted { a, b in
                    if a.isFeatured != b.isFeatured { return a.isFeatured }
                    return false
                }
        case .indoor:
            categoryFiltered = activities.filter { $0.indoor && !$0.isStayHome }
        case .outdoor:
            categoryFiltered = activities.filter { !$0.indoor && !$0.isStayHome }
        case .free:
            categoryFiltered = activities.filter { $0.isFree && !$0.isStayHome }
        case .saved:
            categoryFiltered = activities.filter { savedIDs.contains($0.id) }
        case .seasonal:
            categoryFiltered = activities.filter { $0.isCurrentSeason && !$0.isStayHome }
        case .stayHome:
            categoryFiltered = activities.filter { $0.isStayHome }
        case .nearMe:
            // "Near me" returns all non-stayHome activities; sorting by distance is
            // handled in the view layer using the user's location.
            categoryFiltered = activities.filter { !$0.isStayHome }
        }

        return categoryFiltered
    }

    // MARK: - Surprise Me

    /// Pick a random activity from the currently filtered set.
    ///
    /// When no filter-specific results exist, falls back to all non-stayHome activities.
    /// In bad weather, prefers indoor activities.
    func surpriseMe(weather: Weather?, savedIDs: Set<String>) -> Activity? {
        let pool = filteredActivities(savedIDs: savedIDs)
        guard !pool.isEmpty else { return nil }

        // If weather is bad, prefer indoor activities from the filtered pool
        if let weather, weather.isBadWeather {
            let indoorPool = pool.filter { $0.indoor }
            if !indoorPool.isEmpty {
                return indoorPool.randomElement()
            }
        }

        return pool.randomElement()
    }

    // MARK: - Loading

    /// Load activities for the given city and language.
    ///
    /// Strategy: show cached data immediately, then fetch fresh data in the background.
    @MainActor
    func loadActivities(city: City, language: AppLanguage) async {
        let cacheKey = CacheKey.activities(city: city)

        // 1. Show cached data immediately
        let cached: ActivitiesResponse? = await CacheManager.shared.get(
            ActivitiesResponse.self,
            key: cacheKey,
            ttl: .activities
        )
        if let cached {
            self.activitiesData = cached
        }

        // 2. Fetch fresh data from the API
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchActivities(
                city: city,
                language: language
            )

            self.activitiesData = response

            // Cache the fresh response
            await CacheManager.shared.set(response, key: cacheKey)

            self.error = nil
        } catch {
            // Only set error if we have no cached data to show
            if self.activitiesData == nil {
                // Try stale cache before showing error
                let stale: ActivitiesResponse? = await CacheManager.shared.getStale(ActivitiesResponse.self, key: cacheKey)
                if let stale {
                    self.activitiesData = stale
                } else {
                    self.error = error.localizedDescription
                }
            }
        }

        isLoading = false
    }
}
