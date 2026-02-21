import SwiftUI

/// Root view with tab navigation
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab(tabLabel(.news), systemImage: AppTab.news.sfSymbol, value: .news) {
                NavigationStack {
                    NewsView()
                }
            }

            Tab(tabLabel(.activities), systemImage: AppTab.activities.sfSymbol, value: .activities) {
                NavigationStack {
                    ActivitiesView()
                }
            }

            Tab(tabLabel(.events), systemImage: AppTab.events.sfSymbol, value: .events) {
                NavigationStack {
                    EventsView()
                }
            }

            Tab(tabLabel(.weather), systemImage: AppTab.weather.sfSymbol, value: .weather) {
                NavigationStack {
                    WeatherTabView()
                }
            }

            Tab(tabLabel(.more), systemImage: AppTab.more.sfSymbol, value: .more) {
                NavigationStack {
                    MoreView()
                }
            }
        }
        .tint(.purple)
    }

    private func tabLabel(_ tab: AppTab) -> String {
        appState.language == .en ? tab.label : tab.labelDE
    }
}

/// Weather tab — switches between Sunshine and Snow views
struct WeatherTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSegment: WeatherSegment = .sunshine

    enum WeatherSegment: String, CaseIterable {
        case sunshine, snow

        var label: String {
            switch self {
            case .sunshine: return "Sunshine"
            case .snow: return "Snow"
            }
        }

        var labelDE: String {
            switch self {
            case .sunshine: return "Sonnenschein"
            case .snow: return "Schnee"
            }
        }

        var sfSymbol: String {
            switch self {
            case .sunshine: return "sun.max.fill"
            case .snow: return "snowflake"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedSegment) {
                ForEach(WeatherSegment.allCases, id: \.self) { segment in
                    Label(
                        appState.language == .en ? segment.label : segment.labelDE,
                        systemImage: segment.sfSymbol
                    ).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch selectedSegment {
            case .sunshine:
                SunshineView()
            case .snow:
                SnowView()
            }
        }
        .navigationTitle(appState.localized(en: "Where to go?", de: "Wohin?"))
        .navigationBarTitleDisplayMode(.large)
    }
}

/// More tab — links to Weekend, Lunch, Deals, Settings
struct MoreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                NavigationLink {
                    WeekendView()
                } label: {
                    Label(appState.localized(en: "Weekend Planner", de: "Wochenendplaner"), systemImage: "calendar.badge.clock")
                }

                NavigationLink {
                    LunchView()
                } label: {
                    Label(appState.localized(en: "Lunch", de: "Mittagessen"), systemImage: "fork.knife")
                }

                NavigationLink {
                    DealsView()
                } label: {
                    Label(appState.localized(en: "Deals & Free", de: "Angebote & Gratis"), systemImage: "tag")
                }
            }

            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label(appState.localized(en: "Settings", de: "Einstellungen"), systemImage: "gear")
                }
            }
        }
        .navigationTitle(appState.localized(en: "More", de: "Mehr"))
    }
}
