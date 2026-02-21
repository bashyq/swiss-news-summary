import Foundation
import CoreLocation

// MARK: - Snow Response

/// Response from GET /snow?lang={en|de}
struct SnowResponse: Codable {
    let destinations: [SnowDestination]
    let weekDates: WeekDates
    let timestamp: String
}

struct WeekDates: Codable {
    let monday: String
    let sunday: String
}

// MARK: - Snow Destination

struct SnowDestination: Codable, Identifiable {
    let id: String
    let name: String
    let nameDE: String?
    let lat: Double
    let lon: Double
    let region: String
    let regionDE: String?
    let driveMinutes: Int
    let altitude: Int
    let forecast: [SnowDayForecast]
    let snowfallWeekTotal: Double
    let snowDepthCm: Double?

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

    /// Snowfall level category
    var snowfallLevel: SnowfallLevel {
        if snowfallWeekTotal > 30 { return .heavy }
        if snowfallWeekTotal > 10 { return .moderate }
        return .light
    }

    /// Distance from a reference point
    func distance(from location: CLLocation) -> Double {
        let destLocation = CLLocation(latitude: lat, longitude: lon)
        return location.distance(from: destLocation)
    }
}

struct SnowDayForecast: Codable, Identifiable {
    let date: String
    let snowfallCm: Double
    let weatherCode: Int
    let tempMax: Double
    let tempMin: Double

    var id: String { date }

    var dateParsed: Date? { DateHelpers.parseISO(date) }

    var sfSymbol: String {
        Weather(temperature: tempMax, description: "", weatherCode: weatherCode, windSpeed: 0, hourly: nil).sfSymbol
    }
}

// MARK: - Snowfall Level

enum SnowfallLevel {
    case heavy    // >30cm
    case moderate // 10-30cm
    case light    // <10cm

    var label: String {
        switch self {
        case .heavy: return "Heavy snow"
        case .moderate: return "Moderate snow"
        case .light: return "Light snow"
        }
    }

    var labelDE: String {
        switch self {
        case .heavy: return "Starker Schneefall"
        case .moderate: return "Mäßiger Schneefall"
        case .light: return "Leichter Schneefall"
        }
    }
}

// MARK: - Snow Filters

enum SnowFilter: String, CaseIterable {
    case all
    case heavy    // >30cm
    case moderate // 10-30cm
    case light    // <10cm

    var displayName: String {
        switch self {
        case .all: return "All"
        case .heavy: return "Heavy (>30cm)"
        case .moderate: return "Moderate (10-30cm)"
        case .light: return "Light (<10cm)"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle"
        case .heavy: return "Stark (>30cm)"
        case .moderate: return "Mäßig (10-30cm)"
        case .light: return "Leicht (<10cm)"
        }
    }
}

enum SnowSort: String, CaseIterable {
    case snowfall
    case distance

    var displayName: String {
        switch self {
        case .snowfall: return "By snowfall"
        case .distance: return "By distance"
        }
    }

    var displayNameDE: String {
        switch self {
        case .snowfall: return "Nach Schneefall"
        case .distance: return "Nach Entfernung"
        }
    }
}
