import Foundation

// MARK: - Top-Level News Response

/// Response from GET /?lang={en|de}&city={cityId}
struct NewsResponse: Codable, Sendable {
    let weather: Weather
    let transport: Transport
    let holidays: [Holiday]
    let schoolHolidays: [SchoolHoliday]
    let history: HistoryFact
    let categories: NewsCategories
    let trending: TrendingTopic?
    let briefing: Briefing?
    let weekendBrief: WeekendBrief?
    let city: CityInfo
    let timestamp: String
}

// MARK: - Weather

struct Weather: Codable, Sendable {
    let temperature: Double
    let description: String
    let weatherCode: Int
    let windSpeed: Double
    let hourly: [HourlyWeather]?

    /// WMO weather code -> SF Symbol name
    var sfSymbol: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1: return "sun.min.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45: return "cloud.fog.fill"
        case 48: return "cloud.fog.fill"
        case 51: return "cloud.drizzle.fill"
        case 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61: return "cloud.rain.fill"
        case 63: return "cloud.rain.fill"
        case 65: return "cloud.heavyrain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71: return "cloud.snow.fill"
        case 73: return "cloud.snow.fill"
        case 75: return "snowflake"
        case 77: return "snowflake"
        case 80: return "cloud.sun.rain.fill"
        case 81: return "cloud.rain.fill"
        case 82: return "cloud.heavyrain.fill"
        case 85: return "cloud.snow.fill"
        case 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.rain.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    /// Whether conditions are considered "bad" (rainy or cold)
    var isBadWeather: Bool {
        temperature < 5 || [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99].contains(weatherCode)
    }
}

struct HourlyWeather: Codable, Identifiable, Sendable {
    let time: String
    let temperature: Double
    let weatherCode: Int

    var id: String { time }

    var hour: Int? {
        // Handles both "2026-02-21T14:00" and "14:00" formats
        if let tIndex = time.lastIndex(of: "T") {
            let hourStr = time[time.index(after: tIndex)...].prefix(2)
            return Int(hourStr)
        }
        // Plain "HH:MM" format
        return Int(time.prefix(2))
    }

    var sfSymbol: String {
        let base = Weather(temperature: temperature, description: "", weatherCode: weatherCode, windSpeed: 0, hourly: nil).sfSymbol
        // Use night variants for hours outside daylight (before 7 or after 20)
        guard let h = hour else { return base }
        let isNight = h < 7 || h >= 21
        if isNight {
            switch base {
            case "sun.max.fill", "sun.min.fill": return "moon.stars.fill"
            case "cloud.sun.fill": return "cloud.moon.fill"
            case "cloud.sun.rain.fill": return "cloud.moon.rain.fill"
            default: return base
            }
        }
        return base
    }
}

// MARK: - Transport

struct Transport: Codable, Sendable {
    let delays: [TrainDelay]
    let summary: TransportSummary

    enum CodingKeys: String, CodingKey {
        case delays, summary
    }

    init(delays: [TrainDelay], summary: TransportSummary) {
        self.delays = delays
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        delays = try container.decode([TrainDelay].self, forKey: .delays)
        // Handle summary being either an object, a string, or null gracefully
        if let obj = try? container.decode(TransportSummary.self, forKey: .summary) {
            summary = obj
        } else {
            summary = TransportSummary(totalDelayed: 0, maxDelay: 0, status: "none")
        }
    }
}

struct TrainDelay: Codable, Identifiable, Sendable {
    let line: String
    let destination: String
    let delay: Int
    let scheduledTime: String

    var id: String { "\(line)-\(scheduledTime)" }
}

struct TransportSummary: Codable, Sendable {
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

struct Holiday: Codable, Identifiable, Sendable {
    let name: String
    let nameDE: String?
    let daysUntil: Int
    let date: String
    var cantons: [String]? = nil
    var national: Bool? = nil
    var isToday: Bool? = nil

    var id: String { name }

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE ?? name
        }
    }
}

struct SchoolHoliday: Codable, Identifiable, Sendable {
    let name: String
    let nameDE: String
    let startDate: String
    let endDate: String
    let type: String

    var id: String { name }

    var startDateParsed: Date? { DateHelpers.parseISO(startDate) }
    var endDateParsed: Date? { DateHelpers.parseISO(endDate) }

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE
        }
    }
}

// MARK: - History

struct HistoryFact: Codable, Sendable {
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

struct NewsCategories: Codable, Sendable {
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

struct NewsItem: Codable, Identifiable, Sendable {
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
        guard let publishedAt,
              let date = DateHelpers.parseISODateTime(publishedAt) ?? DateHelpers.parseISO(publishedAt)
        else { return nil }
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

struct TrendingTopic: Codable, Sendable {
    let topic: String?
    let topicDE: String?
    let headline: String?
    let headlineDE: String?
    let url: String?

    func localizedTopic(language: AppLanguage) -> String? {
        switch language {
        case .en: return topic ?? headline
        case .de: return topicDE ?? headlineDE ?? topic ?? headline
        }
    }
}

struct Briefing: Codable, Sendable {
    let topStory: BriefingItem?
    let dailyPick: DailyPick?

    func localizedStory(language: AppLanguage) -> String? {
        topStory?.headline
    }
}

struct BriefingItem: Codable, Sendable {
    let headline: String
    let summary: String
    let source: String
    let url: String
    let sentiment: String
}

/// Weather+time-aware activity recommendation from the API
struct DailyPick: Codable, Sendable {
    let activityId: String
    let name: String
    let nameDE: String
    let reason: String
    let reasonDE: String
    let emoji: String
    let indoor: Bool
    let category: String

    func localizedName(language: AppLanguage) -> String {
        language == .de ? nameDE : name
    }

    func localizedReason(language: AppLanguage) -> String {
        language == .de ? reasonDE : reason
    }
}

// MARK: - Weekend Brief

/// Weekend weather + events summary, null on Sundays
struct WeekendBrief: Codable, Sendable {
    let saturday: WeekendBriefDay?
    let sunday: WeekendBriefDay?
    let events: [WeekendBriefEvent]
    let satDate: String
    let sunDate: String
}

struct WeekendBriefDay: Codable, Sendable {
    let date: String
    let weatherCode: Int
    let tempMax: Int
    let tempMin: Int
    let description: String?

    /// WMO weather code -> SF Symbol
    var sfSymbol: String {
        Weather(temperature: Double(tempMax), description: description ?? "", weatherCode: weatherCode, windSpeed: 0, hourly: nil).sfSymbol
    }
}

struct WeekendBriefEvent: Codable, Identifiable, Sendable {
    let name: String
    let nameDE: String?
    let startDate: String
    let endDate: String?
    let toddlerFriendly: Bool?
    let free: Bool?

    var id: String { name }

    func localizedName(language: AppLanguage) -> String {
        language == .de ? (nameDE ?? name) : name
    }
}

// MARK: - City Info

struct CityInfo: Codable, Sendable {
    let id: String
    let name: String
}
