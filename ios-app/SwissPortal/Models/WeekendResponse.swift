import Foundation

// MARK: - Weekend Response

/// Response from GET /weekend?lang={en|de}&city={cityId}
struct WeekendResponse: Codable {
    let saturday: WeekendDay
    let sunday: WeekendDay
    let city: CityInfo
    let timestamp: String
}

struct WeekendDay: Codable {
    let date: String
    let weather: DayWeather?
    let plan: DayPlan
    var holidays: [Holiday]? = nil
}

struct DayWeather: Codable {
    let date: String?
    let weatherCode: Int
    let tempMax: Double
    let tempMin: Double
    let description: String

    var sfSymbol: String {
        Weather(temperature: tempMax, description: "", weatherCode: weatherCode, windSpeed: 0, hourly: nil).sfSymbol
    }

    func localizedDescription(language: AppLanguage) -> String {
        return description
    }
}

struct DayPlan: Codable {
    let morning: PlannedActivity?
    let afternoon: PlannedActivity?
}

struct PlannedActivity: Codable, Identifiable {
    let id: String
    let name: String
    var nameDE: String? = nil
    let description: String
    var descriptionDE: String? = nil
    let indoor: Bool
    var duration: String? = nil
    var price: String? = nil
    var ageRange: String? = nil
    var category: String? = nil
    var lat: Double? = nil
    var lon: Double? = nil
    var url: String? = nil
    var free: Bool? = nil

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE ?? name
        }
    }

    func localizedDescription(language: AppLanguage) -> String {
        switch language {
        case .en: return description
        case .de: return descriptionDE ?? description
        }
    }
}
