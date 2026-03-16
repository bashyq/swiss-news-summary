import SwiftUI
import EventKit

/// Settings view with city picker, language picker, theme picker, upcoming holidays, about section, and cache management.
///
/// Displayed as its own tab. All preferences are persisted
/// through `AppState` which syncs to `UserDefaults`.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showClearCacheAlert = false
    @State private var showClearDiscardedAlert = false
    @State private var cacheCleared = false
    @State private var discardedCleared = false
    @State private var showHomeAddressSheet = false
    @State private var calendars: [EKCalendar] = []

    var body: some View {
        @Bindable var state = appState

        List {
            // 1. City picker
            citySection(state: $state)

            // 2. Home address
            homeAddressSection

            // 3. Language picker
            languageSection(state: $state)

            // 3. Theme picker
            themeSection(state: $state)

            // 4. Calendar
            calendarSection

            // 5. About section
            aboutSection

            // 8. Clear cache
            cacheSection
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showHomeAddressSheet) {
            HomeAddressSheet()
                .environment(appState)
                .presentationDetents([.large])
        }
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
        .alert(
            appState.localized(en: "Clear Discarded Events", de: "Verworfene Ereignisse löschen"),
            isPresented: $showClearDiscardedAlert
        ) {
            Button(appState.localized(en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(appState.localized(en: "Clear", de: "Löschen"), role: .destructive) {
                CalendarDiscardStore.shared.clearAll()
                withAnimation { discardedCleared = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { discardedCleared = false }
                }
            }
        } message: {
            Text(appState.localized(
                en: "Previously discarded calendar events will appear again on next sync.",
                de: "Zuvor verworfene Kalenderereignisse werden beim nächsten Sync wieder angezeigt."
            ))
        }
        .onAppear {
            if CalendarService.shared.hasAccess {
                calendars = CalendarService.shared.allCalendars()
            }
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

    // MARK: - Home Address Section

    private var homeAddressSection: some View {
        Section {
            if let name = appState.homeAddressName {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.znInk)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        showHomeAddressSheet = true
                    } label: {
                        Text(appState.localized(en: "Change", de: "Ändern"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.znNavy)
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                    appState.clearHomeAddress()
                } label: {
                    Label(
                        appState.localized(en: "Remove Home Address", de: "Heimadresse entfernen"),
                        systemImage: "trash"
                    )
                    .font(.subheadline)
                }
            } else {
                Button {
                    showHomeAddressSheet = true
                } label: {
                    Label(
                        appState.localized(en: "Set Home Address", de: "Heimadresse festlegen"),
                        systemImage: "plus.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.znNavy)
                }
            }
        } header: {
            Label(
                appState.localized(en: "Home", de: "Zuhause"),
                systemImage: "house"
            )
        } footer: {
            Text(appState.localized(
                en: "Used to show travel time home after your last activity.",
                de: "Wird verwendet, um die Reisezeit nach Hause nach der letzten Aktivität anzuzeigen."
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

    // MARK: - Calendar Section

    private var calendarSection: some View {
        Section {
            if CalendarService.shared.hasAccess {
                // Default calendar display
                HStack {
                    Text(appState.localized(en: "Default calendar", de: "Standardkalender"))
                        .font(.subheadline)
                    Spacer()
                    Text(CalendarService.shared.defaultCalendar?.title ?? "—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Clear discarded events
                Button(role: .destructive) {
                    showClearDiscardedAlert = true
                } label: {
                    HStack {
                        Label(
                            appState.localized(en: "Clear Discarded Events", de: "Verworfene Ereignisse löschen"),
                            systemImage: "arrow.counterclockwise"
                        )
                        .font(.subheadline)
                        Spacer()
                        if discardedCleared {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.znPositive)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            } else {
                Button {
                    Task {
                        let granted = await CalendarService.shared.requestAccess()
                        if granted {
                            calendars = CalendarService.shared.allCalendars()
                        }
                    }
                } label: {
                    Label(
                        appState.localized(en: "Enable Calendar Access", de: "Kalenderzugriff aktivieren"),
                        systemImage: "calendar.badge.plus"
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.znNavy)
                }
            }
        } header: {
            Label(
                appState.localized(en: "Calendar", de: "Kalender"),
                systemImage: "calendar"
            )
        } footer: {
            Text(appState.localized(
                en: "Sync your calendar events as anchors and export your day plan.",
                de: "Synchronisiere Kalenderereignisse als Anker und exportiere deinen Tagesplan."
            ))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text(appState.localized(en: "App", de: "App"))
                    .font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Znüni")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Was lauft hüt?")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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
                            .foregroundStyle(.znPositive)
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
