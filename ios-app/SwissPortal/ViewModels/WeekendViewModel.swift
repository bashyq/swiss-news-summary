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

    /// Shuffle the weekend plan by randomly swapping morning/afternoon activities.
    ///
    /// Applies a random local permutation of the four activity slots
    /// (Saturday morning, Saturday afternoon, Sunday morning, Sunday afternoon)
    /// so each shuffle produces a visibly different plan.
    @MainActor
    func shuffle(city: City, language: AppLanguage) async {
        guard var data = weekendData else { return }

        // Collect all available activities into a pool
        var pool: [PlannedActivity] = []
        if let a = data.saturday.plan.morning { pool.append(a) }
        if let a = data.saturday.plan.afternoon { pool.append(a) }
        if let a = data.sunday.plan.morning { pool.append(a) }
        if let a = data.sunday.plan.afternoon { pool.append(a) }

        guard pool.count >= 2 else { return }

        // Shuffle the pool
        pool.shuffle()

        // Redistribute back into the four slots
        let satMorning = pool.indices.contains(0) ? pool[0] : nil
        let satAfternoon = pool.indices.contains(1) ? pool[1] : nil
        let sunMorning = pool.indices.contains(2) ? pool[2] : nil
        let sunAfternoon = pool.indices.contains(3) ? pool[3] : nil

        data = WeekendResponse(
            saturday: WeekendDay(
                date: data.saturday.date,
                weather: data.saturday.weather,
                plan: DayPlan(morning: satMorning, afternoon: satAfternoon),
                holidays: data.saturday.holidays
            ),
            sunday: WeekendDay(
                date: data.sunday.date,
                weather: data.sunday.weather,
                plan: DayPlan(morning: sunMorning, afternoon: sunAfternoon),
                holidays: data.sunday.holidays
            ),
            city: data.city,
            timestamp: data.timestamp
        )

        self.weekendData = data
    }
}
