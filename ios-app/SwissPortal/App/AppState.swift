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
    /// Incremented when the user re-taps the already-selected tab (used to reset tab state)
    var tabRetapCount: Int = 0
    
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
        case "weather", "weekend": selectedTab = .weekend
        case "lunch": selectedTab = .explore
        case "events": selectedTab = .explore
        case "settings": selectedTab = .settings
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
    case weekend // sunshine + snow + planner
    case settings

    var label: String {
        switch self {
        case .news: return "News"
        case .activities: return "Activities"
        case .explore: return "Explore"
        case .weekend: return "Weekend"
        case .settings: return "Settings"
        }
    }

    var labelDE: String {
        switch self {
        case .news: return "Nachrichten"
        case .activities: return "Aktivitäten"
        case .explore: return "Entdecken"
        case .weekend: return "Wochenende"
        case .settings: return "Einstellungen"
        }
    }

    var sfSymbol: String {
        switch self {
        case .news: return "square.grid.2x2"
        case .activities: return "star"
        case .explore: return "mountain.2"
        case .weekend: return "person"
        case .settings: return "gearshape"
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


