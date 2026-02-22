import SwiftUI

/// Root view with tab navigation
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        ZStack(alignment: .bottom) {
            TabView(selection: $state.selectedTab) {
                NavigationStack {
                    NewsView()
                }
                .tabItem {
                    Label(tabLabel(.news), systemImage: AppTab.news.sfSymbol)
                }
                .tag(AppTab.news)

                NavigationStack {
                    ActivitiesView()
                }
                .tabItem {
                    Label(tabLabel(.activities), systemImage: AppTab.activities.sfSymbol)
                }
                .tag(AppTab.activities)

                NavigationStack {
                    LunchView()
                }
                .tabItem {
                    Label(tabLabel(.lunch), systemImage: AppTab.lunch.sfSymbol)
                }
                .tag(AppTab.lunch)

                NavigationStack {
                    WeatherTabView()
                }
                .tabItem {
                    Label(tabLabel(.weather), systemImage: AppTab.weather.sfSymbol)
                }
                .tag(AppTab.weather)

                NavigationStack {
                    MoreView()
                }
                .tabItem {
                    Label(tabLabel(.more), systemImage: AppTab.more.sfSymbol)
                }
                .tag(AppTab.more)
            }
            .tint(.purple)

            ToastOverlay()
                .padding(.bottom, 50)
        }
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
                    EventsView()
                } label: {
                    Label(appState.localized(en: "Events", de: "Events"), systemImage: "calendar")
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
