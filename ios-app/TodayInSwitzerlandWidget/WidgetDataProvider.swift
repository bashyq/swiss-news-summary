import Foundation
import WidgetKit

/// Shared data provider for widget timeline updates.
/// Fetches data from the same Cloudflare Worker API.
struct WidgetDataProvider {
    private static let baseURL = "https://swiss-news-worker.swissnews.workers.dev"

    /// Fetch news summary for widget
    static func fetchNews(city: String, language: String) async -> WidgetNewsEntry? {
        guard let url = URL(string: "\(baseURL)/?lang=\(language)&city=\(city)") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WidgetNewsResponse.self, from: data)

            let topHeadline = response.categories.topStories?.first?.headline
                ?? response.categories.politics?.first?.headline
                ?? "No headlines"

            return WidgetNewsEntry(
                date: Date(),
                temperature: response.weather.temperature,
                weatherCode: response.weather.weatherCode,
                weatherDescription: response.weather.description,
                topHeadline: topHeadline,
                transportStatus: response.transport.summary.status,
                transportDelays: response.transport.summary.totalDelayed,
                cityName: response.city.name
            )
        } catch {
            return nil
        }
    }

    /// Fetch sunshine summary for widget
    static func fetchSunshine(language: String) async -> WidgetSunshineEntry? {
        guard let url = URL(string: "\(baseURL)/sunshine?lang=\(language)") else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WidgetSunshineResponse.self, from: data)

            let topDestinations = response.destinations
                .filter { $0.isBaseline != true }
                .prefix(3)
                .map { WidgetSunshineDestination(name: $0.name, sunshineHours: $0.sunshineHoursTotal, driveMinutes: $0.driveMinutes) }

            let baseline = response.destinations.first { $0.isBaseline == true }

            return WidgetSunshineEntry(
                date: Date(),
                baselineSunshineHours: baseline?.sunshineHoursTotal ?? 0,
                topDestinations: Array(topDestinations)
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Widget Entry Models

struct WidgetNewsEntry: TimelineEntry {
    let date: Date
    let temperature: Double
    let weatherCode: Int
    let weatherDescription: String
    let topHeadline: String
    let transportStatus: String
    let transportDelays: Int
    let cityName: String

    var weatherSFSymbol: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 61, 63, 65, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }

    static let placeholder = WidgetNewsEntry(
        date: Date(),
        temperature: 8,
        weatherCode: 2,
        weatherDescription: "Partly cloudy",
        topHeadline: "Loading headlines...",
        transportStatus: "none",
        transportDelays: 0,
        cityName: "Zürich"
    )
}

struct WidgetSunshineEntry: TimelineEntry {
    let date: Date
    let baselineSunshineHours: Double
    let topDestinations: [WidgetSunshineDestination]

    static let placeholder = WidgetSunshineEntry(
        date: Date(),
        baselineSunshineHours: 4.5,
        topDestinations: [
            WidgetSunshineDestination(name: "Lugano", sunshineHours: 18.5, driveMinutes: 150),
            WidgetSunshineDestination(name: "Locarno", sunshineHours: 17.2, driveMinutes: 160),
            WidgetSunshineDestination(name: "Chur", sunshineHours: 15.0, driveMinutes: 80),
        ]
    )
}

struct WidgetSunshineDestination {
    let name: String
    let sunshineHours: Double
    let driveMinutes: Int
}

// MARK: - Lightweight Codable models for widget (subset of full models)

struct WidgetNewsResponse: Codable {
    let weather: WidgetWeather
    let transport: WidgetTransport
    let categories: WidgetCategories
    let city: WidgetCityInfo
}

struct WidgetWeather: Codable {
    let temperature: Double
    let description: String
    let weatherCode: Int
}

struct WidgetTransport: Codable {
    let summary: WidgetTransportSummary
}

struct WidgetTransportSummary: Codable {
    let totalDelayed: Int
    let status: String
}

struct WidgetCategories: Codable {
    let topStories: [WidgetNewsItem]?
    let politics: [WidgetNewsItem]?
}

struct WidgetNewsItem: Codable {
    let headline: String
}

struct WidgetCityInfo: Codable {
    let name: String
}

struct WidgetSunshineResponse: Codable {
    let destinations: [WidgetSunshineDest]
}

struct WidgetSunshineDest: Codable {
    let name: String
    let driveMinutes: Int
    let sunshineHoursTotal: Double
    let isBaseline: Bool?
}
