import Foundation

/// ViewModel for the Deals & Free view — manages filtering of static deals data
/// by type, city, and seasonal validity.
///
/// Unlike other ViewModels, this one has no API call — deals are static data
/// bundled in the app via `DealsData.all`.
@Observable
final class DealsViewModel {

    // MARK: - Published State

    /// Current filter for deal type
    var filter: DealFilter = .all

    // MARK: - Filtering

    /// Returns deals filtered by city relevance, current month validity, and the active type filter.
    ///
    /// Results are sorted by type: free first, then deal, then tip.
    ///
    /// - Parameter city: The currently selected city.
    /// - Returns: Filtered and sorted array of deals.
    func filteredDeals(city: City) -> [Deal] {
        // Start with all bundled deals
        var deals = DealsData.all

        // Filter by city (deals with city=="all" apply to every city)
        deals = deals.filter { $0.appliesTo(city: city) }

        // Filter by current month validity
        deals = deals.filter { $0.isCurrentlyValid }

        // Filter by deal type
        switch filter {
        case .all:
            break
        case .free:
            deals = deals.filter { $0.type == .free }
        case .deal:
            deals = deals.filter { $0.type == .deal }
        case .tip:
            deals = deals.filter { $0.type == .tip }
        }

        // Sort by type: free first, then deal, then tip
        deals.sort { lhs, rhs in
            let order: [DealType: Int] = [.free: 0, .deal: 1, .tip: 2]
            return (order[lhs.type] ?? 3) < (order[rhs.type] ?? 3)
        }

        return deals
    }
}
