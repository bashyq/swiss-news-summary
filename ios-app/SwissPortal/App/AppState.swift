import SwiftUI
import WidgetKit

// MARK: - UserDefaults Keys

enum StorageKeys {
    static let city = "city"
    static let language = "language"
    static let theme = "theme"
    static let savedActivities = "savedActivities"
    static let savedLunch = "savedLunch"
    static let customActivities = "customActivities"
    static let customLunch = "customLunch"
    static let familySession = "familySession"

    /// App group suite for sharing settings with widgets
    static let widgetSuite = "group.com.todayinswitzerland"
}

/// Global app state — persisted across launches via @AppStorage
@Observable
final class AppState {
    // Persisted preferences (backed by UserDefaults via manual sync)
    var city: City {
        didSet {
            UserDefaults.standard.set(city.rawValue, forKey: StorageKeys.city)
            Self.syncToWidgetDefaults(key: StorageKeys.city, value: city.rawValue)
        }
    }
    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: StorageKeys.language)
            Self.syncToWidgetDefaults(key: StorageKeys.language, value: language.rawValue)
        }
    }
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: StorageKeys.theme) }
    }
    // Family session for agenda composer
    var familySession: FamilySession {
        didSet { familySession.save() }
    }

    // Transient UI state
    var selectedTab: AppTab = .today
    /// Pending navigation target after tab switch (e.g., "lunch" or "events")
    var pendingExploreRoute: String?
    /// Incremented when the user re-taps the already-selected tab (used to reset tab state)
    var tabRetapCount: Int = 0
    
    var savedActivityIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(savedActivityIDs), forKey: StorageKeys.savedActivities)
        }
    }
    var savedLunchIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(savedLunchIDs), forKey: StorageKeys.savedLunch)
        }
    }

    init() {
        let cityRaw = UserDefaults.standard.string(forKey: StorageKeys.city) ?? "zurich"
        self.city = City(rawValue: cityRaw) ?? .zurich

        let langRaw = UserDefaults.standard.string(forKey: StorageKeys.language) ?? "en"
        self.language = AppLanguage(rawValue: langRaw) ?? .en

        let themeRaw = UserDefaults.standard.string(forKey: StorageKeys.theme) ?? "system"
        self.theme = AppTheme(rawValue: themeRaw) ?? .system

        let savedIDs = UserDefaults.standard.stringArray(forKey: StorageKeys.savedActivities) ?? []
        self.savedActivityIDs = Set(savedIDs)

        let savedLunch = UserDefaults.standard.stringArray(forKey: StorageKeys.savedLunch) ?? []
        self.savedLunchIDs = Set(savedLunch)

        self.familySession = FamilySession.load()

        // Sync current settings to widget shared defaults on launch
        Self.syncToWidgetDefaults(key: StorageKeys.city, value: self.city.rawValue)
        Self.syncToWidgetDefaults(key: StorageKeys.language, value: self.language.rawValue)
    }

    /// Write a value to the shared app group UserDefaults and reload widgets.
    private static func syncToWidgetDefaults(key: String, value: String) {
        UserDefaults(suiteName: StorageKeys.widgetSuite)?.set(value, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
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
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.customActivities),
              var list = try? JSONDecoder().decode([CustomActivity].self, from: data) else { return }
        list.removeAll { $0.id == id }
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.customActivities)
        }
    }

    func deleteCustomLunch(_ id: String) {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.customLunch),
              var list = try? JSONDecoder().decode([CustomLunchSpot].self, from: data) else { return }
        list.removeAll { $0.id == id }
        if let encoded = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.customLunch)
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
        case "news", "today": selectedTab = .today
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
    case today
    case activities
    case explore
    case weekend // sunshine + snow + planner
    case settings

    var label: String {
        switch self {
        case .today: return "Today"
        case .activities: return "Activities"
        case .explore: return "Explore"
        case .weekend: return "Weekend"
        case .settings: return "Settings"
        }
    }

    var labelDE: String {
        switch self {
        case .today: return "Heute"
        case .activities: return "Aktivitäten"
        case .explore: return "Entdecken"
        case .weekend: return "Wochenende"
        case .settings: return "Einstellungen"
        }
    }

    var sfSymbol: String {
        switch self {
        case .today: return "square.grid.2x2"
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


