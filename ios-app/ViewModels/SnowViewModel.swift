import Foundation
import CoreLocation

/// ViewModel for the Snow view — manages fetching, filtering, sorting, and the
/// "fresh powder alert" feature for weekly snowfall forecasts across Swiss ski resorts.
@Observable
final class SnowViewModel {

    // MARK: - Published State

    /// The full snow response from the API (resorts with forecasts, week dates)
    var snowData: SnowResponse?

    /// Current sort order for resort list
    var sort: SnowSort = .snowfall

    /// Current filter for snowfall level
    var filter: SnowFilter = .all

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    /// Whether all resorts are shown (false = top 10 only)
    var showAll: Bool = false

    /// ID of the currently expanded resort card (accordion — only one at a time)
    var expandedResortID: String?

    // MARK: - Filtering & Sorting

    /// Returns resorts filtered by the current `filter` and sorted by the current `sort`.
    ///
    /// When `showAll` is false, results are limited to the first 10.
    ///
    /// - Parameter userLocation: The user's current location, used when sorting by distance.
    /// - Returns: Filtered and sorted array of snow destinations.
    func filteredDestinations(userLocation: CLLocation?) -> [SnowDestination] {
        guard var destinations = snowData?.destinations else { return [] }

        // Apply snowfall filter
        switch filter {
        case .all:
            break
        case .heavy:
            destinations = destinations.filter { $0.snowfallWeekTotal > 30 }
        case .moderate:
            destinations = destinations.filter { $0.snowfallWeekTotal >= 10 && $0.snowfallWeekTotal <= 30 }
        case .light:
            destinations = destinations.filter { $0.snowfallWeekTotal < 10 }
        }

        // Apply sort
        switch sort {
        case .snowfall:
            destinations.sort { $0.snowfallWeekTotal > $1.snowfallWeekTotal }
        case .distance:
            if let location = userLocation {
                destinations.sort { $0.distance(from: location) < $1.distance(from: location) }
            } else {
                // Fallback to drive time when no user location available
                destinations.sort { $0.driveMinutes < $1.driveMinutes }
            }
        }

        // Limit to top 10 when not showing all
        if !showAll {
            destinations = Array(destinations.prefix(10))
        }

        return destinations
    }

    /// Whether the top resort has more than 40cm of weekly snowfall (fresh powder alert).
    var hasPowderAlert: Bool {
        guard let destinations = snowData?.destinations else { return false }

        // Top resort is the one with the most snowfall
        guard let top = destinations.max(by: { $0.snowfallWeekTotal < $1.snowfallWeekTotal }) else {
            return false
        }

        return top.snowfallWeekTotal > 40
    }

    // MARK: - Accordion

    /// Toggle the expanded state of a resort card. Only one card can be expanded at a time.
    ///
    /// - Parameter id: The resort ID to toggle.
    func toggleExpanded(_ id: String) {
        if expandedResortID == id {
            expandedResortID = nil
        } else {
            expandedResortID = id
        }
    }

    // MARK: - Loading

    /// Load snow data for all ski resorts.
    ///
    /// Strategy: show cached data immediately (if available), then try the worker endpoint.
    /// If the worker fails (e.g., rate-limited), fall back to client-side Open-Meteo fetch.
    ///
    /// - Parameters:
    ///   - language: The display language.
    ///   - forceRefresh: If true, bypasses the cache entirely.
    @MainActor
    func loadSnow(language: AppLanguage, forceRefresh: Bool = false) async {
        let cacheKey = CacheKey.snow

        // 1. Show cached data immediately (unless forcing refresh)
        if !forceRefresh {
            let cached: SnowResponse? = await CacheManager.shared.get(
                SnowResponse.self,
                key: cacheKey,
                ttl: .snow
            )
            if let cached {
                self.snowData = cached
            }
        }

        // 2. Fetch fresh data from the worker API
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchSnow(
                language: language,
                forceRefresh: forceRefresh
            )

            self.snowData = response

            // Cache the fresh response
            await CacheManager.shared.set(response, key: cacheKey)

            self.error = nil
        } catch {
            // 3. Fallback: fetch directly from Open-Meteo client-side
            do {
                let fallbackResponse = try await APIClient.shared.fetchSnowClientSide(
                    resorts: SnowResorts.all
                )

                self.snowData = fallbackResponse

                // Cache the fallback response
                await CacheManager.shared.set(fallbackResponse, key: cacheKey)

                self.error = nil
            } catch let fallbackError {
                // Only set error if we have no cached data to show
                if self.snowData == nil {
                    self.error = fallbackError.localizedDescription
                }
            }
        }

        isLoading = false
    }
}
