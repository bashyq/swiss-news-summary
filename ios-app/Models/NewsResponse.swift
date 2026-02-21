import Foundation

// MARK: - Top-Level News Response

/// Response from GET /?lang={en|de}&city={cityId}
struct NewsResponse: Codable {
    let weather: Weather
    let transport: Transport
    let holidays: [Holiday]
    let schoolHolidays: [SchoolHoliday]
    let history: HistoryFact
    let categories: NewsCategories
    let trending: TrendingTopic?
    let briefing: Briefing?
    let city: CityInfo
    let timestamp: String
}

// MARK: - Weather

struct Weather: Codable {
    let temperature: Double
    let description: String
    let weatherCode: Int
    let windSpeed: Double
    let hourly: [HourlyWeather]?

    /// WMO weather code → SF Symbol name
    var sfSymbol: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    /// Whether conditions are considered "bad" (rainy or cold)
    var isBadWeather: Bool {
        temperature < 5 || [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99].contains(weatherCode)
    }
}

struct HourlyWeather: Codable, Identifiable {
    let time: String
    let temperature: Double
    let weatherCode: Int

    var id: String { time }

    var hour: Int? {
        // time format: "2026-02-21T14:00"
        guard let tIndex = time.lastIndex(of: "T") else { return nil }
        let hourStr = time[time.index(after: tIndex)...].prefix(2)
        return Int(hourStr)
    }

    var sfSymbol: String {
        Weather(temperature: temperature, description: "", weatherCode: weatherCode, windSpeed: 0, hourly: nil).sfSymbol
    }
}

// MARK: - Transport

struct Transport: Codable {
    let delays: [TrainDelay]
    let summary: TransportSummary
}

struct TrainDelay: Codable, Identifiable {
    let line: String
    let destination: String
    let delay: Int
    let scheduledTime: String

    var id: String { "\(line)-\(scheduledTime)" }
}

struct TransportSummary: Codable {
    let totalDelayed: Int
    let maxDelay: Int
    let status: String // "none", "minor", "major"

    var statusColor: String {
        switch status {
        case "none": return "green"
        case "minor": return "yellow"
        case "major": return "red"
        default: return "gray"
        }
    }
}

// MARK: - Holidays

struct Holiday: Codable, Identifiable {
    let name: String
    let nameDE: String?
    let daysUntil: Int
    let date: String?

    var id: String { name }

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE ?? name
        }
    }
}

struct SchoolHoliday: Codable, Identifiable {
    let name: String
    let nameDE: String?
    let startDate: String
    let endDate: String
    let type: String?

    var id: String { name }

    var startDateParsed: Date? { DateHelpers.parseISO(startDate) }
    var endDateParsed: Date? { DateHelpers.parseISO(endDate) }

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE ?? name
        }
    }
}

// MARK: - History

struct HistoryFact: Codable {
    let year: Int
    let event: String
    let eventDE: String?

    func localizedEvent(language: AppLanguage) -> String {
        switch language {
        case .en: return event
        case .de: return eventDE ?? event
        }
    }
}

// MARK: - News Categories

struct NewsCategories: Codable {
    let topStories: [NewsItem]?
    let disruptions: [NewsItem]?
    let events: [NewsItem]?
    let politics: [NewsItem]?
    let culture: [NewsItem]?
    let local: [NewsItem]?

    /// All category keys in display order
    static let allKeys: [String] = ["topStories", "politics", "disruptions", "events", "culture", "local"]

    /// Get items for a category key
    func items(for key: String) -> [NewsItem] {
        switch key {
        case "topStories": return topStories ?? []
        case "disruptions": return disruptions ?? []
        case "events": return events ?? []
        case "politics": return politics ?? []
        case "culture": return culture ?? []
        case "local": return local ?? []
        default: return []
        }
    }

    /// Display name for category key
    static func displayName(for key: String, language: AppLanguage) -> String {
        switch (key, language) {
        case ("topStories", .en): return "Top Stories"
        case ("topStories", .de): return "Top-Meldungen"
        case ("politics", .en): return "Politics"
        case ("politics", .de): return "Politik"
        case ("disruptions", .en): return "Disruptions"
        case ("disruptions", .de): return "Störungen"
        case ("events", .en): return "Events"
        case ("events", .de): return "Veranstaltungen"
        case ("culture", .en): return "Culture"
        case ("culture", .de): return "Kultur"
        case ("local", .en): return "Local"
        case ("local", .de): return "Lokal"
        default: return key
        }
    }
}

struct NewsItem: Codable, Identifiable {
    let headline: String
    let headlineDE: String?
    let summary: String
    let summaryDE: String?
    let detail: String?
    let detailDE: String?
    let source: String
    let url: String?
    let sentiment: String?
    let publishedAt: String?

    var id: String { headline }

    func localizedHeadline(language: AppLanguage) -> String {
        switch language {
        case .en: return headline
        case .de: return headlineDE ?? headline
        }
    }

    func localizedSummary(language: AppLanguage) -> String {
        switch language {
        case .en: return summary
        case .de: return summaryDE ?? summary
        }
    }

    func localizedDetail(language: AppLanguage) -> String? {
        switch language {
        case .en: return detail
        case .de: return detailDE ?? detail
        }
    }

    /// Time ago string from publishedAt
    var timeAgo: String? {
        guard let publishedAt, let date = DateHelpers.parseISO(publishedAt) else { return nil }
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }

    var sentimentColor: String {
        switch sentiment {
        case "positive": return "green"
        case "negative": return "red"
        default: return "gray"
        }
    }
}

// MARK: - Trending & Briefing

struct TrendingTopic: Codable {
    let topic: String?
    let topicDE: String?
    let headline: String?
    let headlineDE: String?

    func localizedTopic(language: AppLanguage) -> String? {
        switch language {
        case .en: return topic ?? headline
        case .de: return topicDE ?? headlineDE ?? topic ?? headline
        }
    }
}

struct Briefing: Codable {
    let topStory: String?
    let topStoryDE: String?
    let suggestedActivity: String?
    let suggestedActivityDE: String?

    func localizedStory(language: AppLanguage) -> String? {
        switch language {
        case .en: return topStory
        case .de: return topStoryDE ?? topStory
        }
    }

    func localizedActivity(language: AppLanguage) -> String? {
        switch language {
        case .en: return suggestedActivity
        case .de: return suggestedActivityDE ?? suggestedActivity
        }
    }
}

// MARK: - City Info

struct CityInfo: Codable {
    let id: String
    let name: String
}
