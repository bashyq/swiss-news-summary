import Foundation
import CoreLocation

// MARK: - Activities Response

/// Response from GET /activities?lang={en|de}&city={cityId}
struct ActivitiesResponse: Codable {
    let activities: [Activity]
    let cityEvents: [CityEvent]
    let weather: Weather
    let city: CityInfo
    let timestamp: String
}

// MARK: - Activity

struct Activity: Codable, Identifiable {
    let id: String
    let name: String
    let nameDE: String
    let description: String
    let descriptionDE: String
    let indoor: Bool
    let ageRange: String
    let duration: String
    let price: String
    let priceDE: String?
    let url: String?
    let lat: Double?
    let lon: Double?
    let category: String
    let minAge: Int?
    let maxAge: Int?
    let season: String?
    let free: Bool?
    let recurring: String?
    let stayHome: Bool?
    let availableMonths: [Int]?
    let subcategory: String?
    let materials: String?
    let materialsDE: String?

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE
        }
    }

    func localizedDescription(language: AppLanguage) -> String {
        switch language {
        case .en: return description
        case .de: return descriptionDE
        }
    }

    func localizedPrice(language: AppLanguage) -> String {
        switch language {
        case .en: return price
        case .de: return priceDE ?? price
        }
    }

    func localizedMaterials(language: AppLanguage) -> String? {
        switch language {
        case .en: return materials
        case .de: return materialsDE ?? materials
        }
    }

    /// Whether activity is free (auto-detected from price field)
    var isFree: Bool {
        if let free { return free }
        let p = price.lowercased()
        return p.hasPrefix("free") || p.hasPrefix("gratis")
    }

    /// Coordinate if available
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Distance from a reference point (meters)
    func distance(from location: CLLocation) -> Double? {
        guard let lat, let lon else { return nil }
        let activityLocation = CLLocation(latitude: lat, longitude: lon)
        return location.distance(from: activityLocation)
    }

    /// Whether this activity matches the given age filter
    func matchesAge(_ ageFilter: AgeFilter) -> Bool {
        switch ageFilter {
        case .all: return true
        case .toddler: // 2-3
            return (minAge ?? 0) <= 3
        case .preschool: // 4-5
            return (maxAge ?? 5) >= 4
        }
    }

    /// Whether this activity is currently seasonal (available this month)
    var isCurrentSeason: Bool {
        guard let season else { return true }
        let month = Calendar.current.component(.month, from: Date())
        switch season.lowercased() {
        case "winter": return [12, 1, 2].contains(month)
        case "spring": return [3, 4, 5].contains(month)
        case "summer": return [6, 7, 8].contains(month)
        case "autumn", "fall": return [9, 10, 11].contains(month)
        default: return true
        }
    }

    /// Check if available on a specific date (for recurring activities)
    func isAvailable(on date: Date) -> Bool {
        guard let recurring else { return true }
        let weekday = Calendar.current.component(.weekday, from: date)
        let dayAbbreviations = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let todayAbbr = dayAbbreviations[weekday]
        return recurring.localizedCaseInsensitiveContains(todayAbbr)
    }
}

// MARK: - Age Filter

enum AgeFilter: String, CaseIterable {
    case all
    case toddler  // 2-3
    case preschool // 4-5

    var displayName: String {
        switch self {
        case .all: return "All ages"
        case .toddler: return "2-3 years"
        case .preschool: return "4-5 years"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle Alter"
        case .toddler: return "2-3 Jahre"
        case .preschool: return "4-5 Jahre"
        }
    }
}

// MARK: - Activity Filter

enum ActivityFilter: String, CaseIterable {
    case all
    case nearMe
    case indoor
    case outdoor
    case free
    case saved
    case seasonal
    case stayHome

    var displayName: String {
        switch self {
        case .all: return "All"
        case .nearMe: return "Near me"
        case .indoor: return "Indoor"
        case .outdoor: return "Outdoor"
        case .free: return "Free"
        case .saved: return "Saved"
        case .seasonal: return "Seasonal"
        case .stayHome: return "Stay home"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle"
        case .nearMe: return "In der Nähe"
        case .indoor: return "Indoor"
        case .outdoor: return "Outdoor"
        case .free: return "Gratis"
        case .saved: return "Gespeichert"
        case .seasonal: return "Saisonal"
        case .stayHome: return "Zuhause"
        }
    }

    var sfSymbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .nearMe: return "location"
        case .indoor: return "house"
        case .outdoor: return "sun.max"
        case .free: return "gift"
        case .saved: return "heart.fill"
        case .seasonal: return "leaf"
        case .stayHome: return "sofa"
        }
    }
}

// MARK: - City Event

struct CityEvent: Codable, Identifiable {
    let id: String
    let name: String
    let nameDE: String
    let city: String
    let startDate: String
    let endDate: String
    let description: String
    let descriptionDE: String
    let toddlerFriendly: Bool
    let free: Bool
    let url: String?

    var startDateParsed: Date? { DateHelpers.parseISO(startDate) }
    var endDateParsed: Date? { DateHelpers.parseISO(endDate) }

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE
        }
    }

    func localizedDescription(language: AppLanguage) -> String {
        switch language {
        case .en: return description
        case .de: return descriptionDE
        }
    }

    /// Whether this event overlaps with a given date
    func overlaps(with date: Date) -> Bool {
        guard let start = startDateParsed, let end = endDateParsed else { return false }
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        let eventStart = calendar.startOfDay(for: start)
        let eventEnd = calendar.startOfDay(for: end)
        return dateStart >= eventStart && dateStart <= eventEnd
    }
}

// MARK: - Event Filter

/// Typed filter replacing string-based filter for the Events view.
enum EventFilter: String, CaseIterable {
    case all
    case holidays
    case schoolHolidays
    case events
    case recurring
    case seasonal
    case festivals

    var displayName: String {
        switch self {
        case .all: return "All"
        case .holidays: return "Holidays"
        case .schoolHolidays: return "School Holidays"
        case .events: return "Events"
        case .recurring: return "Recurring"
        case .seasonal: return "Seasonal"
        case .festivals: return "Festivals"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle"
        case .holidays: return "Feiertage"
        case .schoolHolidays: return "Schulferien"
        case .events: return "Veranstaltungen"
        case .recurring: return "Wiederkehrend"
        case .seasonal: return "Saisonal"
        case .festivals: return "Festivals"
        }
    }

    var sfSymbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .holidays: return "flag"
        case .schoolHolidays: return "graduationcap"
        case .events: return "star"
        case .recurring: return "arrow.triangle.2.circlepath"
        case .seasonal: return "leaf"
        case .festivals: return "party.popper"
        }
    }
}

// MARK: - Event Item

/// Typed wrapper replacing `[Any]` for heterogeneous event lists.
enum EventItem: Identifiable {
    case holiday(Holiday)
    case schoolHoliday(SchoolHoliday)
    case cityEvent(CityEvent)
    case activity(Activity)

    var id: String {
        switch self {
        case .holiday(let h): return "holiday-\(h.id)"
        case .schoolHoliday(let sh): return "schoolHoliday-\(sh.id)"
        case .cityEvent(let e): return "cityEvent-\(e.id)"
        case .activity(let a): return "activity-\(a.id)"
        }
    }
}
