import Foundation

/// ViewModel for the Deals & Free view — manages fetching and filtering deals
/// from the API with a fallback to bundled `DealsData.all`.
@Observable
final class DealsViewModel {

    // MARK: - Published State

    /// All deals (from API or bundled fallback)
    var deals: [Deal]?

    /// Current filter for deal type
    var filter: DealFilter = .all

    /// Whether a network fetch is in progress
    var isLoading: Bool = false

    /// Human-readable error message if the last fetch failed
    var error: String?

    // MARK: - Filtering

    /// Returns deals filtered by city relevance, current month validity, and the active type filter.
    ///
    /// Results are sorted by type: free first, then deal, then tip.
    ///
    /// - Parameter city: The currently selected city.
    /// - Returns: Filtered and sorted array of deals.
    func filteredDeals(city: City) -> [Deal] {
        var result = deals ?? DealsData.all

        // Filter by city (deals with city=="all" apply to every city)
        result = result.filter { $0.appliesTo(city: city) }

        // Filter by current month validity
        result = result.filter { $0.isCurrentlyValid }

        // Filter by deal type
        switch filter {
        case .all:
            break
        case .free:
            result = result.filter { $0.type == .free }
        case .deal:
            result = result.filter { $0.type == .deal }
        case .tip:
            result = result.filter { $0.type == .tip }
        }

        // Sort by type: free first, then deal, then tip
        result.sort { lhs, rhs in
            let order: [DealType: Int] = [.free: 0, .deal: 1, .tip: 2]
            return (order[lhs.type] ?? 3) < (order[rhs.type] ?? 3)
        }

        return result
    }

    // MARK: - Loading

    /// Load deals from the API with cache and bundled fallback.
    @MainActor
    func loadDeals(city: City, language: AppLanguage) async {
        let cacheKey = CacheKey.deals(city: city)

        // 1. Show cached data immediately
        let cached: DealsResponse? = await CacheManager.shared.get(
            DealsResponse.self,
            key: cacheKey,
            ttl: .deals
        )
        if let cached {
            self.deals = cached.deals
        }

        // 2. Fetch fresh data from the API
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchDeals(
                city: city,
                language: language
            )
            self.deals = response.deals
            await CacheManager.shared.set(response, key: cacheKey)
            self.error = nil
        } catch {
            // Fall back to stale cache, then bundled data
            if self.deals == nil {
                let stale: DealsResponse? = await CacheManager.shared.getStale(DealsResponse.self, key: cacheKey)
                if let stale {
                    self.deals = stale.deals
                }
                // If still nil, filteredDeals() falls back to DealsData.all
            }
        }

        isLoading = false
    }
}
