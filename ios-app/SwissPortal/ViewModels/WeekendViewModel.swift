import Foundation

/// ViewModel for the Weekend Planner view — manages fetching and refreshing weekend activity plans.
@Observable
final class WeekendViewModel {

    // MARK: - Published State

    /// The full weekend response from the API (Saturday + Sunday plans with weather)
    var weekendData: WeekendResponse?

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    // MARK: - Loading

    /// Load the weekend plan for the given city and language.
    ///
    /// Strategy: show cached data immediately (if available), then fetch fresh data in the background.
    @MainActor
    func loadWeekend(city: City, language: AppLanguage) async {
        let cacheKey = CacheKey.weekend(city: city)

        // 1. Show cached data immediately
        let cached: WeekendResponse? = await CacheManager.shared.get(
            WeekendResponse.self,
            key: cacheKey,
            ttl: .weekend
        )
        if let cached {
            self.weekendData = cached
        }

        // 2. Fetch fresh data from the API
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchWeekend(
                city: city,
                language: language
            )

            self.weekendData = response

            // Cache the fresh response
            await CacheManager.shared.set(response, key: cacheKey)

            self.error = nil
        } catch {
            // Only set error if we have no cached data to show
            if self.weekendData == nil {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Shuffle

    /// Force-refresh the weekend plan to get new random activity picks.
    ///
    /// Bypasses the cache entirely by removing the cached entry first,
    /// then fetching fresh data from the worker.
    @MainActor
    func shuffle(city: City, language: AppLanguage) async {
        let cacheKey = CacheKey.weekend(city: city)

        // Clear the cache to ensure fresh data
        await CacheManager.shared.remove(key: cacheKey)

        // Fetch fresh data
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchWeekend(
                city: city,
                language: language
            )

            self.weekendData = response

            // Cache the new response
            await CacheManager.shared.set(response, key: cacheKey)

            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
