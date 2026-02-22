import Foundation
import CoreLocation

// MARK: - Sunshine Response

/// Response from GET /sunshine?lang={en|de}
struct SunshineResponse: Codable {
    let destinations: [SunshineDestination]
    let weekendDates: WeekendDates
    let timestamp: String
}

struct WeekendDates: Codable {
    let friday: String
    let saturday: String
    let sunday: String
}

// MARK: - Sunshine Destination

struct SunshineDestination: Codable, Identifiable {
    let id: String
    let name: String
    let nameDE: String?
    let lat: Double
    let lon: Double
    let region: String
    let regionDE: String?
    let driveMinutes: Int
    let forecast: [SunshineDayForecast]
    let sunshineHoursTotal: Double
    let isBaseline: Bool?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE ?? name
        }
    }

    func localizedRegion(language: AppLanguage) -> String {
        switch language {
        case .en: return region
        case .de: return regionDE ?? region
        }
    }

    /// Sunshine level category
    var sunshineLevel: SunshineLevel {
        if sunshineHoursTotal > 6 * Double(forecast.count) / 3.0 {
            return .sunny
        } else if sunshineHoursTotal > 3 * Double(forecast.count) / 3.0 {
            return .partly
        } else {
            return .cloudy
        }
    }

    /// Distance from a reference point
    func distance(from location: CLLocation) -> Double {
        let destLocation = CLLocation(latitude: lat, longitude: lon)
        return location.distance(from: destLocation)
    }
}

struct SunshineDayForecast: Codable, Identifiable {
    let date: String
    let weatherCode: Int
    let tempMax: Double
    let tempMin: Double
    let sunshineHours: Double
    let precipMm: Double
    let sunnyHours: [Int]?
    let description: SunshineDescription?

    var id: String { date }

    var dateParsed: Date? { DateHelpers.parseISO(date) }

    var sfSymbol: String {
        Weather(temperature: tempMax, description: "", weatherCode: weatherCode, windSpeed: 0, hourly: nil).sfSymbol
    }
}

struct SunshineDescription: Codable {
    let en: String
    let de: String

    func localized(language: AppLanguage) -> String {
        switch language {
        case .en: return en
        case .de: return de
        }
    }
}

// MARK: - Sunshine Level

enum SunshineLevel {
    case sunny   // >6h per day average
    case partly  // 3-6h
    case cloudy  // <3h

    var label: String {
        switch self {
        case .sunny: return "Sunny"
        case .partly: return "Partly sunny"
        case .cloudy: return "Cloudy"
        }
    }

    var labelDE: String {
        switch self {
        case .sunny: return "Sonnig"
        case .partly: return "Teilweise sonnig"
        case .cloudy: return "Bewölkt"
        }
    }
}

// MARK: - Sunshine Filters

enum SunshineFilter: String, CaseIterable {
    case all
    case sunny   // >6h total
    case partly  // 3-6h total
    case cloudy  // <3h total

    var displayName: String {
        switch self {
        case .all: return "All"
        case .sunny: return "Sunny (>6h)"
        case .partly: return "Partly (3-6h)"
        case .cloudy: return "Cloudy (<3h)"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle"
        case .sunny: return "Sonnig (>6h)"
        case .partly: return "Teilweise (3-6h)"
        case .cloudy: return "Bewölkt (<3h)"
        }
    }
}

enum SunshineSort: String, CaseIterable {
    case sunshine
    case distance

    var displayName: String {
        switch self {
        case .sunshine: return "By sunshine"
        case .distance: return "By distance"
        }
    }

    var displayNameDE: String {
        switch self {
        case .sunshine: return "Nach Sonnenschein"
        case .distance: return "Nach Entfernung"
        }
    }
}

// MARK: - Destination Highlights

/// Curated toddler-friendly attractions per sunshine destination
struct DestinationHighlight: Identifiable {
    let id = UUID()
    let name: String
    let nameDE: String
    let type: String  // "playground", "museum", "nature", "restaurant"
    let description: String
    let descriptionDE: String
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

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

    var sfSymbol: String {
        switch type {
        case "playground": return "figure.play"
        case "museum": return "building.columns"
        case "nature": return "leaf"
        case "restaurant": return "fork.knife"
        default: return "mappin"
        }
    }
}
