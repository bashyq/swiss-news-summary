import SwiftUI

/// Settings view with city picker, language picker, theme picker, upcoming holidays, about section, and cache management.
///
/// Accessed from the "More" tab via NavigationLink. All preferences are persisted
/// through `AppState` which syncs to `UserDefaults`.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showClearCacheAlert = false
    @State private var cacheCleared = false

    var body: some View {
        @Bindable var state = appState

        List {
            // 1. City picker
            citySection(state: state)

            // 2. Language picker
            languageSection(state: state)

            // 3. Theme picker
            themeSection(state: state)

            // 4. Upcoming holidays
            holidaysSection

            // 5. About section
            aboutSection

            // 6. Clear cache
            cacheSection
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .alert(
            appState.localized(en: "Clear Cache", de: "Cache leeren"),
            isPresented: $showClearCacheAlert
        ) {
            Button(appState.localized(en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(appState.localized(en: "Clear", de: "Leeren"), role: .destructive) {
                clearCache()
            }
        } message: {
            Text(appState.localized(
                en: "This will remove all cached data. Fresh data will be fetched on next load.",
                de: "Dies entfernt alle zwischengespeicherten Daten. Neue Daten werden beim nachsten Laden abgerufen."
            ))
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "Settings", de: "Einstellungen")
    }

    // MARK: - City Section

    private func citySection(state: Bindable<AppState>) -> some View {
        Section {
            Picker(
                appState.localized(en: "City", de: "Stadt"),
                selection: state.city
            ) {
                ForEach(City.allCases) { city in
                    Text(city.localizedName(language: appState.language))
                        .tag(city)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Label(
                appState.localized(en: "Location", de: "Standort"),
                systemImage: "mappin.circle"
            )
        } footer: {
            Text(appState.localized(
                en: "Choose your city for local news, weather, and activities.",
                de: "Wahle deine Stadt fur lokale Nachrichten, Wetter und Aktivitaten."
            ))
        }
    }

    // MARK: - Language Section

    private func languageSection(state: Bindable<AppState>) -> some View {
        Section {
            Picker(
                appState.localized(en: "Language", de: "Sprache"),
                selection: state.language
            ) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label(
                appState.localized(en: "Language", de: "Sprache"),
                systemImage: "globe"
            )
        }
    }

    // MARK: - Theme Section

    private func themeSection(state: Bindable<AppState>) -> some View {
        Section {
            Picker(
                appState.localized(en: "Appearance", de: "Darstellung"),
                selection: state.theme
            ) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label(
                appState.localized(en: "Appearance", de: "Darstellung"),
                systemImage: "paintbrush"
            )
        }
    }

    // MARK: - Holidays Section

    private var holidaysSection: some View {
        Section {
            let holidays = upcomingHolidays
            if holidays.isEmpty {
                Text(appState.localized(
                    en: "No upcoming holidays",
                    de: "Keine bevorstehenden Feiertage"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                ForEach(holidays) { holiday in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(holiday.localizedName(language: appState.language))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let date = holiday.date {
                                Text(date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        daysUntilBadge(holiday.daysUntil)
                    }
                }
            }
        } header: {
            Label(
                appState.localized(en: "Upcoming Holidays", de: "Kommende Feiertage"),
                systemImage: "calendar.badge.checkmark"
            )
        }
    }

    private func daysUntilBadge(_ days: Int) -> some View {
        let text: String
        if days == 0 {
            text = appState.localized(en: "Today", de: "Heute")
        } else if days == 1 {
            text = appState.localized(en: "Tomorrow", de: "Morgen")
        } else {
            text = appState.localized(en: "\(days) days", de: "\(days) Tage")
        }

        let color: Color = days <= 7 ? .green : (days <= 30 ? .orange : .secondary)

        return BadgeView(text: text, color: color)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text(appState.localized(en: "App", de: "App"))
                    .font(.subheadline)
                Spacer()
                Text("Today in Switzerland")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(appState.localized(en: "Version", de: "Version"))
                    .font(.subheadline)
                Spacer()
                Text(appVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com/bashyq/swiss-news-summary")!) {
                HStack {
                    Text("GitHub")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label(
                appState.localized(en: "About", de: "Info"),
                systemImage: "info.circle"
            )
        }
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
        Section {
            Button(role: .destructive) {
                showClearCacheAlert = true
            } label: {
                HStack {
                    Label(
                        appState.localized(en: "Clear Cache", de: "Cache leeren"),
                        systemImage: "trash"
                    )
                    .font(.subheadline)
                    Spacer()
                    if cacheCleared {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        } header: {
            Label(
                appState.localized(en: "Storage", de: "Speicher"),
                systemImage: "internaldrive"
            )
        } footer: {
            Text(appState.localized(
                en: "Cached data helps the app load faster. Clearing it will require fresh downloads.",
                de: "Zwischengespeicherte Daten helfen der App, schneller zu laden. Beim Leeren werden neue Downloads benotigt."
            ))
        }
    }

    // MARK: - Actions

    private func clearCache() {
        Task {
            await CacheManager.shared.clearAll()
            withAnimation {
                cacheCleared = true
            }
            // Reset checkmark after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    cacheCleared = false
                }
            }
        }
    }

    // MARK: - Data

    /// Static upcoming Swiss holidays sorted by days until.
    /// This mirrors the holidays data from the worker's data.js.
    private var upcomingHolidays: [Holiday] {
        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)

        let allHolidays: [(name: String, nameDE: String, month: Int, day: Int)] = [
            ("New Year's Day", "Neujahr", 1, 1),
            ("Berchtoldstag", "Berchtoldstag", 1, 2),
            ("Good Friday", "Karfreitag", 0, 0),       // Calculated below
            ("Easter Monday", "Ostermontag", 0, 0),     // Calculated below
            ("Labour Day", "Tag der Arbeit", 5, 1),
            ("Ascension Day", "Auffahrt", 0, 0),        // Calculated below
            ("Whit Monday", "Pfingstmontag", 0, 0),     // Calculated below
            ("Swiss National Day", "Bundesfeiertag", 8, 1),
            ("Christmas Day", "Weihnachten", 12, 25),
            ("St. Stephen's Day", "Stephanstag", 12, 26),
        ]

        // Calculate Easter-dependent dates
        let easterDate = calculateEaster(year: year)

        var holidays: [Holiday] = []

        for h in allHolidays {
            let dateComponents: DateComponents
            let dateStr: String

            switch h.name {
            case "Good Friday":
                if let date = calendar.date(byAdding: .day, value: -2, to: easterDate) {
                    let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                    if daysUntil >= 0 {
                        holidays.append(Holiday(
                            name: h.name,
                            nameDE: h.nameDE,
                            daysUntil: daysUntil,
                            date: DateHelpers.toISO(date)
                        ))
                    }
                }
                continue
            case "Easter Monday":
                if let date = calendar.date(byAdding: .day, value: 1, to: easterDate) {
                    let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                    if daysUntil >= 0 {
                        holidays.append(Holiday(
                            name: h.name,
                            nameDE: h.nameDE,
                            daysUntil: daysUntil,
                            date: DateHelpers.toISO(date)
                        ))
                    }
                }
                continue
            case "Ascension Day":
                if let date = calendar.date(byAdding: .day, value: 39, to: easterDate) {
                    let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                    if daysUntil >= 0 {
                        holidays.append(Holiday(
                            name: h.name,
                            nameDE: h.nameDE,
                            daysUntil: daysUntil,
                            date: DateHelpers.toISO(date)
                        ))
                    }
                }
                continue
            case "Whit Monday":
                if let date = calendar.date(byAdding: .day, value: 50, to: easterDate) {
                    let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                    if daysUntil >= 0 {
                        holidays.append(Holiday(
                            name: h.name,
                            nameDE: h.nameDE,
                            daysUntil: daysUntil,
                            date: DateHelpers.toISO(date)
                        ))
                    }
                }
                continue
            default:
                dateComponents = DateComponents(year: year, month: h.month, day: h.day)
                guard let date = calendar.date(from: dateComponents) else { continue }
                let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0

                // If holiday already passed this year, try next year
                if daysUntil < 0 {
                    let nextYearComponents = DateComponents(year: year + 1, month: h.month, day: h.day)
                    guard let nextDate = calendar.date(from: nextYearComponents) else { continue }
                    let nextDaysUntil = calendar.dateComponents([.day], from: today, to: nextDate).day ?? 0
                    holidays.append(Holiday(
                        name: h.name,
                        nameDE: h.nameDE,
                        daysUntil: nextDaysUntil,
                        date: DateHelpers.toISO(nextDate)
                    ))
                    continue
                }

                dateStr = DateHelpers.toISO(date)
                holidays.append(Holiday(
                    name: h.name,
                    nameDE: h.nameDE,
                    daysUntil: daysUntil,
                    date: dateStr
                ))
            }
        }

        // Sort by days until and take first 5
        return holidays
            .sorted { $0.daysUntil < $1.daysUntil }
            .prefix(5)
            .map { $0 }
    }

    /// Anonymous Gregorian Easter computation (Computus)
    private func calculateEaster(year: Int) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - App Version

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState())
    }
}
