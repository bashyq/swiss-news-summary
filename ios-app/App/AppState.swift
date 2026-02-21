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

    /// Localized string helper
    func localized(en: String, de: String) -> String {
        language == .en ? en : de
    }
}

// MARK: - App Tab

enum AppTab: String, CaseIterable {
    case news
    case activities
    case events
    case weather // sunshine + snow
    case more

    var label: String {
        switch self {
        case .news: return "News"
        case .activities: return "Activities"
        case .events: return "Events"
        case .weather: return "Weather"
        case .more: return "More"
        }
    }

    var labelDE: String {
        switch self {
        case .news: return "Nachrichten"
        case .activities: return "Aktivitäten"
        case .events: return "Events"
        case .weather: return "Wetter"
        case .more: return "Mehr"
        }
    }

    var sfSymbol: String {
        switch self {
        case .news: return "newspaper"
        case .activities: return "figure.play"
        case .events: return "calendar"
        case .weather: return "sun.max"
        case .more: return "ellipsis.circle"
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
