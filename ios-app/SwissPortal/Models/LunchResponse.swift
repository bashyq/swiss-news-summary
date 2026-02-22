import Foundation
import CoreLocation

// MARK: - Lunch Response

/// Response from GET /lunch?lang={en|de}&city={cityId}
struct LunchResponse: Codable {
    let spots: [LunchSpot]
    let city: CityInfo
    let timestamp: String?
}

// MARK: - Lunch Spot

struct LunchSpot: Codable, Identifiable {
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
    let vegetarian: Bool?
    let phone: String?
    let website: String?

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

// MARK: - Lunch Filter

enum LunchFilter: String, CaseIterable {
    case all
    case saved
    case open
    case outdoor
    case vegetarian

    var displayName: String {
        switch self {
        case .all: return "All"
        case .saved: return "Saved"
        case .open: return "Open now"
        case .outdoor: return "Outdoor"
        case .vegetarian: return "Vegetarian"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle"
        case .saved: return "Gespeichert"
        case .open: return "Jetzt offen"
        case .outdoor: return "Terrasse"
        case .vegetarian: return "Vegetarisch"
        }
    }

    var sfSymbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .saved: return "heart.fill"
        case .open: return "clock"
        case .outdoor: return "sun.max"
        case .vegetarian: return "leaf"
        }
    }
}
