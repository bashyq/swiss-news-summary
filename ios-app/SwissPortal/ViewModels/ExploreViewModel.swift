import Foundation
import CoreLocation
import SwiftUI

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

    // MARK: - Category Helpers

    /// Items filtered by ExploreCategory.
    func items(for category: ExploreCategory, city: City, language: AppLanguage) -> [ExploreItem] {
        switch category {
        case .museums:
            return activityItems().filter { item in
                if case .activity(let a) = item { return a.category.lowercased() == "museums" || a.category.lowercased() == "museum" }
                return false
            }
        case .parks:
            return activityItems().filter { item in
                if case .activity(let a) = item { return a.category.lowercased() == "parks" || a.category.lowercased() == "playgrounds" || !a.indoor }
                return false
            }
        case .restaurants:
            return dealItems(city: city).filter { item in
                if case .deal(let d, _) = item { return d.category.lowercased() == "restaurants" || d.category.lowercased() == "outdoor" }
                return false
            }
        case .events:
            return eventItems(city: city)
        case .deals:
            return dealItems(city: city)
        }
    }

    /// Count of items for a category.
    func count(for category: ExploreCategory, city: City) -> Int {
        switch category {
        case .museums:
            return activityItems().filter { item in
                if case .activity(let a) = item { return a.category.lowercased() == "museums" || a.category.lowercased() == "museum" }
                return false
            }.count
        case .parks:
            return activityItems().filter { item in
                if case .activity(let a) = item { return !a.indoor }
                return false
            }.count
        case .restaurants:
            return dealItems(city: city).count
        case .events:
            return eventItems(city: city).count
        case .deals:
            return dealItems(city: city).count
        }
    }

    /// Items sorted by distance from the given location.
    func nearYouItems(location: CLLocation, city: City, language: AppLanguage, limit: Int = 8) -> [ExploreItem] {
        let all = filteredItems(city: city, language: language)
        return Array(
            all.sorted { a, b in
                let aDist = location.distance(from: CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude))
                let bDist = location.distance(from: CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude))
                return aDist < bDist
            }
            .prefix(limit)
        )
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
        case .events: return "Family Events"
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
        case .activity: return .positive
        case .event: return .navy
        case .deal(let d, _):
            return d.type == .free ? .positive : .terracotta
        }
    }

    enum MarkerColor {
        case positive, navy, terracotta

        var tint: (light: String, dark: String) {
            switch self {
            case .positive: return ("4A8C5C", "5CA06B")   // znPositive-aligned
            case .navy: return ("1A3A5C", "3A6A8C")       // znNavy
            case .terracotta: return ("C4623A", "D4825A")  // znTerracotta
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

// MARK: - Explore Category

/// Category for "Browse by type" grid in the Explore view.
enum ExploreCategory: String, CaseIterable, Identifiable {
    case museums
    case parks
    case restaurants
    case events
    case deals

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .museums: return "Museums"
        case .parks: return "Parks & Playgrounds"
        case .restaurants: return "Restaurants"
        case .events: return "Events"
        case .deals: return "Deals & Free"
        }
    }

    var displayNameDE: String {
        switch self {
        case .museums: return "Museen"
        case .parks: return "Parks & Spielplätze"
        case .restaurants: return "Restaurants"
        case .events: return "Familienevents"
        case .deals: return "Angebote & Gratis"
        }
    }

    var sfSymbol: String {
        switch self {
        case .museums: return "building.columns.fill"
        case .parks: return "leaf.fill"
        case .restaurants: return "fork.knife"
        case .events: return "calendar"
        case .deals: return "tag.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .museums: return [.znNavy, .znNavy.opacity(0.7)]
        case .parks: return [.znPositive, .znPositive.opacity(0.7)]
        case .restaurants: return [.znTerracotta, .znTerracotta.opacity(0.7)]
        case .events: return [.znNavy.opacity(0.8), .znNavy.opacity(0.5)]
        case .deals: return [.znPositive.opacity(0.8), .znPositive.opacity(0.5)]
        }
    }
}
