import Foundation
import CoreLocation

/// All supported Swiss cities with their configuration
enum City: String, CaseIterable, Codable, Identifiable {
    case zurich
    case basel
    case bern
    case geneva
    case lausanne
    case luzern
    case winterthur

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zurich: return "Zürich"
        case .basel: return "Basel"
        case .bern: return "Bern"
        case .geneva: return "Geneva"
        case .lausanne: return "Lausanne"
        case .luzern: return "Luzern"
        case .winterthur: return "Winterthur"
        }
    }

    var displayNameDE: String {
        switch self {
        case .zurich: return "Zürich"
        case .basel: return "Basel"
        case .bern: return "Bern"
        case .geneva: return "Genf"
        case .lausanne: return "Lausanne"
        case .luzern: return "Luzern"
        case .winterthur: return "Winterthur"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .zurich: return CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)
        case .basel: return CLLocationCoordinate2D(latitude: 47.5596, longitude: 7.5886)
        case .bern: return CLLocationCoordinate2D(latitude: 46.9480, longitude: 7.4474)
        case .geneva: return CLLocationCoordinate2D(latitude: 46.2044, longitude: 6.1432)
        case .lausanne: return CLLocationCoordinate2D(latitude: 46.5197, longitude: 6.6323)
        case .luzern: return CLLocationCoordinate2D(latitude: 47.0502, longitude: 8.3093)
        case .winterthur: return CLLocationCoordinate2D(latitude: 47.4985, longitude: 8.7243)
        }
    }

    var station: String {
        switch self {
        case .zurich: return "Zürich HB"
        case .basel: return "Basel SBB"
        case .bern: return "Bern"
        case .geneva: return "Genève"
        case .lausanne: return "Lausanne"
        case .luzern: return "Luzern"
        case .winterthur: return "Winterthur"
        }
    }

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return displayName
        case .de: return displayNameDE
        }
    }
}

/// Supported languages
enum AppLanguage: String, CaseIterable, Codable {
    case en
    case de

    var displayName: String {
        switch self {
        case .en: return "English"
        case .de: return "Deutsch"
        }
    }
}
