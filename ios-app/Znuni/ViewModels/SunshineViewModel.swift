import Foundation
import CoreLocation

/// ViewModel for the Sunshine view — manages fetching, filtering, sorting, and the
/// "nearest sunny escape" feature for weekend sunshine forecasts across Swiss destinations.
@Observable
final class SunshineViewModel {

    // MARK: - Published State

    /// The full sunshine response from the API (destinations with forecasts, weekend dates)
    var sunshineData: SunshineResponse?

    /// Current sort order for destination list
    var sort: SunshineSort = .sunshine

    /// Current filter for sunshine level
    var filter: SunshineFilter = .all

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    /// Whether all destinations are shown (false = top 10 non-baseline only)
    var showAll: Bool = false

    /// ID of the currently expanded destination card (accordion — only one at a time)
    var expandedDestinationID: String?

    // MARK: - Filtering & Sorting

    /// Returns destinations filtered by the current `filter` and sorted by the current `sort`.
    ///
    /// The baseline destination (Zürich) is always kept first regardless of filter or sort.
    /// When `showAll` is false, non-baseline destinations are limited to the first 10.
    ///
    /// - Parameter userLocation: The user's current location, used when sorting by distance.
    /// - Returns: Filtered and sorted array of sunshine destinations.
    func filteredDestinations(userLocation: CLLocation?) -> [SunshineDestination] {
        guard let destinations = sunshineData?.destinations else { return [] }

        // Separate baseline from rest
        let baseline = destinations.first { $0.isBaseline == true }
        var rest = destinations.filter { $0.isBaseline != true }

        // Apply sunshine filter
        switch filter {
        case .all:
            break
        case .sunny:
            rest = rest.filter { $0.sunshineHoursTotal > 6 }
        case .partly:
            rest = rest.filter { $0.sunshineHoursTotal >= 3 && $0.sunshineHoursTotal <= 6 }
        case .cloudy:
            rest = rest.filter { $0.sunshineHoursTotal < 3 }
        }

        // Apply sort
        switch sort {
        case .sunshine:
            rest.sort { $0.sunshineHoursTotal > $1.sunshineHoursTotal }
        case .distance:
            if let location = userLocation {
                rest.sort { $0.distance(from: location) < $1.distance(from: location) }
            } else {
                // Fallback to drive time when no user location available
                rest.sort { $0.driveMinutes < $1.driveMinutes }
            }
        }

        // Limit to top 10 when not showing all
        if !showAll {
            rest = Array(rest.prefix(10))
        }

        // Baseline always first
        if let baseline {
            return [baseline] + rest
        }
        return rest
    }

    /// Returns the nearest sunny escape when the Zürich baseline has less than 6 hours of sunshine.
    ///
    /// Finds the closest destination (by drive time) that has more sunshine hours than the baseline.
    /// Returns `nil` if the baseline has 6+ hours or no better destination exists.
    ///
    /// - Parameter userLocation: The user's current location (unused — sorts by driveMinutes).
    /// - Returns: The nearest destination with more sun, or `nil`.
    func nearestSunnyEscape(userLocation: CLLocation?) -> SunshineDestination? {
        guard let destinations = sunshineData?.destinations else { return nil }

        // Find the baseline (Zürich)
        guard let baseline = destinations.first(where: { $0.isBaseline == true }) else {
            return nil
        }

        // Only suggest escape if baseline has <6h sunshine
        guard baseline.sunshineHoursTotal < 6 else { return nil }

        // Find destinations with more sun than baseline, sorted by drive time
        let sunnier = destinations
            .filter { $0.isBaseline != true && $0.sunshineHoursTotal > baseline.sunshineHoursTotal }
            .sorted { $0.driveMinutes < $1.driveMinutes }

        return sunnier.first
    }

    // MARK: - Accordion

    /// Toggle the expanded state of a destination card. Only one card can be expanded at a time.
    ///
    /// - Parameter id: The destination ID to toggle.
    func toggleExpanded(_ id: String) {
        if expandedDestinationID == id {
            expandedDestinationID = nil
        } else {
            expandedDestinationID = id
        }
    }

    // MARK: - Loading

    /// Load sunshine data for all destinations.
    ///
    /// Strategy: show cached data immediately (if available), then try the worker endpoint.
    /// If the worker fails (e.g., rate-limited), fall back to client-side Open-Meteo fetch.
    ///
    /// - Parameters:
    ///   - language: The display language.
    ///   - forceRefresh: If true, bypasses the cache entirely.
    @MainActor
    func loadSunshine(language: AppLanguage, forceRefresh: Bool = false) async {
        let cacheKey = CacheKey.sunshine

        // 1. Show cached data immediately (unless forcing refresh)
        if !forceRefresh {
            let cached: SunshineResponse? = await CacheManager.shared.get(
                SunshineResponse.self,
                key: cacheKey,
                ttl: .sunshine
            )
            if let cached {
                self.sunshineData = cached
            }
        }

        // 2. Fetch fresh data from the worker API
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchSunshine(
                language: language,
                forceRefresh: forceRefresh
            )

            self.sunshineData = response

            // Cache the fresh response
            await CacheManager.shared.set(response, key: cacheKey)

            self.error = nil
        } catch {
            // 3. Fallback: fetch directly from Open-Meteo client-side
            do {
                let fallbackResponse = try await APIClient.shared.fetchSunshineClientSide(
                    destinations: SunshineDestinations.all
                )

                self.sunshineData = fallbackResponse

                // Cache the fallback response
                await CacheManager.shared.set(fallbackResponse, key: cacheKey)

                self.error = nil
            } catch let fallbackError {
                // Only set error if we have no cached data to show
                if self.sunshineData == nil {
                    self.error = fallbackError.localizedDescription
                }
            }
        }

        isLoading = false
    }
}
