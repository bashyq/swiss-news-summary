import Foundation
import CoreLocation

/// ViewModel for the Explore view — aggregates activities, upcoming city events, and deals onto a single map.
@Observable
final class ExploreViewModel {

    // MARK: - State

    var activitiesData: ActivitiesResponse?
    var isLoading = false
    var error: String?
    var filter: ExploreFilter = .all

    // MARK: - Explore Items

    /// All items for the current city, filtered by the active filter.
    func filteredItems(city: City, language: AppLanguage) -> [ExploreItem] {
        var items: [ExploreItem] = []

        switch filter {
        case .all:
            items.append(contentsOf: activityItems())
            items.append(contentsOf: eventItems(city: city))
            items.append(contentsOf: dealItems(city: city))
        case .activities:
            items.append(contentsOf: activityItems())
        case .events:
            items.append(contentsOf: eventItems(city: city))
        case .deals:
            items.append(contentsOf: dealItems(city: city))
        }

        return items
    }

    // MARK: - Data Sources

    private func activityItems() -> [ExploreItem] {
        guard let activities = activitiesData?.activities else { return [] }
        return activities
            .filter { $0.coordinate != nil && !$0.isStayHome }
            .map { ExploreItem.activity($0) }
    }

    /// City events happening within the next 7 days.
    /// Events don't have coordinates, so we place them near the city center with a small offset.
    private func eventItems(city: City) -> [ExploreItem] {
        guard let events = activitiesData?.cityEvents else { return [] }
        let now = Date()
        let sevenDaysLater = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        return events.compactMap { event in
            guard let start = event.startDateParsed, let end = event.endDateParsed else { return nil }
            // Show events that overlap with the next 7 days
            let windowStart = Calendar.current.startOfDay(for: now)
            let windowEnd = Calendar.current.startOfDay(for: sevenDaysLater)
            let eventStart = Calendar.current.startOfDay(for: start)
            let eventEnd = Calendar.current.startOfDay(for: end)
            guard eventEnd >= windowStart && eventStart <= windowEnd else { return nil }

            return ExploreItem.event(event, city: city)
        }
    }

    /// Deals valid for the current city and month.
    private func dealItems(city: City) -> [ExploreItem] {
        DealsData.all
            .filter { $0.appliesTo(city: city) && $0.isCurrentlyValid }
            .map { ExploreItem.deal($0, city: city) }
    }

    // MARK: - Loading

    @MainActor
    func loadData(city: City, language: AppLanguage) async {
        let cacheKey = CacheKey.activities(city: city)

        // Show cached data immediately
        let cached: ActivitiesResponse? = await CacheManager.shared.get(
            ActivitiesResponse.self,
            key: cacheKey,
            ttl: .activities
        )
        if let cached {
            self.activitiesData = cached
        }

        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.fetchActivities(
                city: city,
                language: language
            )
            self.activitiesData = response
            await CacheManager.shared.set(response, key: cacheKey)
            self.error = nil
        } catch {
            if self.activitiesData == nil {
                let stale: ActivitiesResponse? = await CacheManager.shared.getStale(
                    ActivitiesResponse.self, key: cacheKey
                )
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

// MARK: - Explore Filter

enum ExploreFilter: String, CaseIterable {
    case all
    case activities
    case events
    case deals

    var displayName: String {
        switch self {
        case .all: return "All"
        case .activities: return "Activities"
        case .events: return "Events"
        case .deals: return "Deals"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle"
        case .activities: return "Aktivitäten"
        case .events: return "Events"
        case .deals: return "Angebote"
        }
    }

    var sfSymbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .activities: return "sparkles"
        case .events: return "calendar"
        case .deals: return "tag"
        }
    }
}

// MARK: - Explore Item

/// A unified item shown on the Explore map and list.
enum ExploreItem: Identifiable {
    case activity(Activity)
    case event(CityEvent, city: City)
    case deal(Deal, city: City)

    var id: String {
        switch self {
        case .activity(let a): return "act-\(a.id)"
        case .event(let e, _): return "evt-\(e.id)"
        case .deal(let d, _): return "deal-\(d.id)"
        }
    }

    /// Map coordinate — activities have real coords; events/deals use city center with deterministic offset.
    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .activity(let a):
            return a.coordinate ?? CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)
        case .event(_, let city):
            let center = city.coordinate
            let offset = pseudoRandomOffset(for: id)
            return CLLocationCoordinate2D(
                latitude: center.latitude + offset.lat,
                longitude: center.longitude + offset.lon
            )
        case .deal(_, let city):
            let center = city.coordinate
            let offset = pseudoRandomOffset(for: id)
            return CLLocationCoordinate2D(
                latitude: center.latitude + offset.lat,
                longitude: center.longitude + offset.lon
            )
        }
    }

    var name: String {
        switch self {
        case .activity(let a): return a.name
        case .event(let e, _): return e.name
        case .deal(let d, _): return d.name
        }
    }

    func localizedName(language: AppLanguage) -> String {
        switch self {
        case .activity(let a): return a.localizedName(language: language)
        case .event(let e, _): return e.localizedName(language: language)
        case .deal(let d, _): return d.localizedName(language: language)
        }
    }

    var markerColor: MarkerColor {
        switch self {
        case .activity: return .green
        case .event: return .purple
        case .deal(let d, _):
            return d.type == .free ? .green : .blue
        }
    }

    enum MarkerColor {
        case green, purple, blue

        var tint: (light: String, dark: String) {
            switch self {
            case .green: return ("34C759", "30D158")
            case .purple: return ("AF52DE", "BF5AF2")
            case .blue: return ("007AFF", "0A84FF")
            }
        }
    }

    /// Deterministic small offset so events/deals don't all stack on city center.
    private func pseudoRandomOffset(for id: String) -> (lat: Double, lon: Double) {
        let hash = abs(id.hashValue)
        let latOffset = Double(hash % 1000) / 100_000.0 - 0.005
        let lonOffset = Double((hash / 1000) % 1000) / 100_000.0 - 0.005
        return (latOffset, lonOffset)
    }
}
