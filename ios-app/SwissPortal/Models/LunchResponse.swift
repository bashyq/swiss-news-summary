import Foundation
import CoreLocation

// MARK: - Lunch Response

/// Response from GET /lunch?lang={en|de}&city={cityId}
struct LunchResponse: Codable, Sendable {
    let spots: [LunchSpot]
}

// MARK: - Lunch Spot

struct LunchSpot: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let cuisine: String?
    let cuisineCategory: String?
    let wheelchair: String?
    let outdoorSeating: Bool?
    let takeaway: Bool?
    let openingHours: String?
    let openForLunch: Bool?
    let openForDinner: Bool?
    let kidFriendly: Bool?
    let vegetarian: String?
    let vegan: String?
    let phone: String?
    let website: String?
    let amenity: String
    let rating: Double?
    let ratingCount: Int?
    let permanentlyClosed: Bool?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Distance from a reference point
    func distance(from location: CLLocation) -> Double {
        let spotLocation = CLLocation(latitude: lat, longitude: lon)
        return location.distance(from: spotLocation)
    }

    /// Display cuisine nicely
    var cuisineDisplay: String {
        cuisineCategory?.capitalized ?? cuisine?.capitalized ?? "Restaurant"
    }

    /// Price tier based on amenity type (rough proxy: cafe=1, fast_food=2, restaurant=3)
    var priceTier: Int {
        switch amenity.lowercased() {
        case "cafe": return 1
        case "fast_food": return 2
        default: return 3
        }
    }

    /// SF Symbol for cuisine category
    var cuisineSFSymbol: String {
        switch cuisineCategory?.lowercased() {
        case "swiss": return "flag.fill"
        case "italian": return "fork.knife"
        case "asian": return "takeoutbag.and.cup.and.straw"
        case "kebab": return "flame"
        case "cafe": return "cup.and.saucer"
        case "vegetarian": return "leaf"
        case "fastfood": return "bag"
        default: return "fork.knife"
        }
    }
}

// MARK: - Lunch Toggle Filters (multi-select)

enum LunchToggle: String, CaseIterable, Identifiable {
    case nearMe
    case open
    case terrace
    case saved

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nearMe: return "Near Me"
        case .open: return "Open"
        case .terrace: return "Terrace"
        case .saved: return "Saved"
        }
    }

    var displayNameDE: String {
        switch self {
        case .nearMe: return "In der Nähe"
        case .open: return "Offen"
        case .terrace: return "Terrasse"
        case .saved: return "Gespeichert"
        }
    }

    var sfSymbol: String {
        switch self {
        case .nearMe: return "location"
        case .open: return "clock"
        case .terrace: return "sun.max"
        case .saved: return "heart.fill"
        }
    }
}

// MARK: - Lunch Sort (radio-select, one active at a time)

enum LunchSort: String, CaseIterable, Identifiable {
    case nearest
    case topRated
    case priceLow
    case priceHigh

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nearest: return "Nearest first"
        case .topRated: return "Top rated"
        case .priceLow: return "Price: low to high"
        case .priceHigh: return "Price: high to low"
        }
    }

    var displayNameDE: String {
        switch self {
        case .nearest: return "Nächste zuerst"
        case .topRated: return "Bestbewertet"
        case .priceLow: return "Preis: aufsteigend"
        case .priceHigh: return "Preis: absteigend"
        }
    }

    var sfSymbol: String {
        switch self {
        case .nearest: return "location"
        case .topRated: return "star"
        case .priceLow: return "arrow.up"
        case .priceHigh: return "arrow.down"
        }
    }
}

// MARK: - Cuisine Filter (single-select)

enum CuisineFilter: String, CaseIterable, Identifiable {
    case all
    case italian
    case asian
    case kebab
    case cafe
    case fastfood
    case international

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All cuisines"
        case .italian: return "Italian"
        case .asian: return "Asian"
        case .kebab: return "Kebab"
        case .cafe: return "Café"
        case .fastfood: return "Fast Food"
        case .international: return "International"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle Küchen"
        case .italian: return "Italienisch"
        case .asian: return "Asiatisch"
        case .kebab: return "Kebab"
        case .cafe: return "Café"
        case .fastfood: return "Fast Food"
        case .international: return "International"
        }
    }

    /// Matches against the `cuisineCategory` field from the API
    var apiValue: String? {
        switch self {
        case .all: return nil
        case .italian: return "Italian"
        case .asian: return "Asian"
        case .kebab: return "Kebab"
        case .cafe: return "Cafe"
        case .fastfood: return "Fastfood"
        case .international: return "International"
        }
    }
}
