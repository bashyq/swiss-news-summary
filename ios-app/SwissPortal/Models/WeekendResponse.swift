import Foundation

// MARK: - Weekend Response

/// Response from GET /weekend?lang={en|de}&city={cityId}
struct WeekendResponse: Codable {
    let saturday: WeekendDay
    let sunday: WeekendDay
    let city: CityInfo
    let timestamp: String?
}

struct WeekendDay: Codable {
    let date: String
    let weather: DayWeather
    let plan: DayPlan
}

struct DayWeather: Codable {
    let weatherCode: Int
    let tempMax: Double
    let tempMin: Double
    let description: String?
    let descriptionDE: String?

    var sfSymbol: String {
        Weather(temperature: tempMax, description: "", weatherCode: weatherCode, windSpeed: 0, hourly: nil).sfSymbol
    }

    func localizedDescription(language: AppLanguage) -> String {
        switch language {
        case .en: return description ?? ""
        case .de: return descriptionDE ?? description ?? ""
        }
    }
}

struct DayPlan: Codable {
    let morning: PlannedActivity?
    let afternoon: PlannedActivity?
}

struct PlannedActivity: Codable, Identifiable {
    let id: String
    let name: String
    let nameDE: String?
    let description: String
    let descriptionDE: String?
    let indoor: Bool
    let duration: String?
    let price: String?

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
