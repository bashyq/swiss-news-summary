import SwiftUI

/// Global app state — persisted across launches via @AppStorage
@Observable
final class AppState {
    // Persisted preferences (backed by UserDefaults via manual sync)
    var city: City {
        didSet { UserDefaults.standard.set(city.rawValue, forKey: "city") }
    }
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }

    // Transient UI state
    var selectedTab: AppTab = .news
    var savedActivityIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(savedActivityIDs), forKey: "savedActivities")
        }
    }
    var savedLunchIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(savedLunchIDs), forKey: "savedLunch")
        }
    }
    var lunchRatings: [String: Int] {
        didSet {
            UserDefaults.standard.set(lunchRatings, forKey: "lunchRatings")
        }
    }

    init() {
        let cityRaw = UserDefaults.standard.string(forKey: "city") ?? "zurich"
        self.city = City(rawValue: cityRaw) ?? .zurich

        let langRaw = UserDefaults.standard.string(forKey: "language") ?? "en"
        self.language = AppLanguage(rawValue: langRaw) ?? .en

        let themeRaw = UserDefaults.standard.string(forKey: "theme") ?? "system"
        self.theme = AppTheme(rawValue: themeRaw) ?? .system

        let savedIDs = UserDefaults.standard.stringArray(forKey: "savedActivities") ?? []
        self.savedActivityIDs = Set(savedIDs)

        let savedLunch = UserDefaults.standard.stringArray(forKey: "savedLunch") ?? []
        self.savedLunchIDs = Set(savedLunch)

        self.lunchRatings = UserDefaults.standard.dictionary(forKey: "lunchRatings") as? [String: Int] ?? [:]
    }

    // MARK: - Actions

    func toggleSavedActivity(_ id: String) {
        if savedActivityIDs.contains(id) {
            savedActivityIDs.remove(id)
        } else {
            savedActivityIDs.insert(id)
        }
    }

    func toggleSavedLunch(_ id: String) {
        if savedLunchIDs.contains(id) {
            savedLunchIDs.remove(id)
        } else {
            savedLunchIDs.insert(id)
        }
    }

    func setLunchRating(_ id: String, rating: Int) {
        lunchRatings[id] = rating
    }

    func deleteCustomActivity(_ id: String) {
        let key = "customActivities"
        guard let data = UserDefaults.standard.data(forKey: key),
              var list = try? JSONDecoder().decode([CustomActivity].self, from: data) else { return }
        list.removeAll { $0.id == id }
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func deleteCustomLunch(_ id: String) {
        let key = "customLunch"
        guard let data = UserDefaults.standard.data(forKey: key),
              var list = try? JSONDecoder().decode([CustomLunchSpot].self, from: data) else { return }
        list.removeAll { $0.id == id }
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    /// Localized string helper
    func localized(en: String, de: String) -> String {
        language == .en ? en : de
    }

    // MARK: - Deep Linking

    /// Handle incoming deep links with the `swissportal://` scheme.
    ///
    /// Supported routes:
    /// - `swissportal://news` → News tab
    /// - `swissportal://activities` → Activities tab
    /// - `swissportal://events` → Events tab
    /// - `swissportal://weather` → Weather tab
    /// - `swissportal://activities?city=basel` → switch city + Activities tab
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "swissportal" else { return }

        let host = url.host ?? ""
        switch host {
        case "news": selectedTab = .news
        case "activities": selectedTab = .activities
        case "explore": selectedTab = .explore
        case "weather": selectedTab = .weather
        case "lunch": selectedTab = .more
        case "events": selectedTab = .more
        default: break
        }

        // Parse query params for city
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let cityParam = components.queryItems?.first(where: { $0.name == "city" })?.value,
           let city = City(rawValue: cityParam) {
            self.city = city
        }
    }
}

// MARK: - App Tab

enum AppTab: String, CaseIterable {
    case news
    case activities
    case explore
    case weather // sunshine + snow
    case more

    var label: String {
        switch self {
        case .news: return "News"
        case .activities: return "Activities"
        case .explore: return "Explore"
        case .weather: return "Weather"
        case .more: return "More"
        }
    }

    var labelDE: String {
        switch self {
        case .news: return "Nachrichten"
        case .activities: return "Aktivitäten"
        case .explore: return "Entdecken"
        case .weather: return "Wetter"
        case .more: return "Mehr"
        }
    }

    var sfSymbol: String {
        switch self {
        case .news: return "newspaper.fill"
        case .activities: return "sparkles"
        case .explore: return "map.fill"
        case .weather: return "cloud.sun.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
