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
                .tabItem { tabLabel(.news) }
                .tag(AppTab.news)

                NavigationStack {
                    ActivitiesView()
                }
                .tabItem { tabLabel(.activities) }
                .tag(AppTab.activities)

                NavigationStack {
                    ExploreView()
                }
                .tabItem { tabLabel(.explore) }
                .tag(AppTab.explore)

                NavigationStack {
                    WeatherTabView()
                }
                .tabItem { tabLabel(.weather) }
                .tag(AppTab.weather)

                NavigationStack {
                    MoreView()
                }
                .tabItem { tabLabel(.more) }
                .tag(AppTab.more)
            }
            .tint(.brand)

            ToastOverlay()
                .padding(.bottom, 50)
        }
    }

    /// Tab bar label with icon + text
    private func tabLabel(_ tab: AppTab) -> some View {
        Label(
            appState.language == .en ? tab.label : tab.labelDE,
            systemImage: tab.sfSymbol
        )
    }
}

/// More tab — hub for Lunch, Weekend, Events, Deals, Settings
struct MoreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LunchView()
                } label: {
                    Label(appState.localized(en: "Lunch", de: "Mittagessen"), systemImage: "fork.knife.circle.fill")
                        .foregroundStyle(.primary)
                }

                NavigationLink {
                    WeekendView()
                } label: {
                    Label(appState.localized(en: "Weekend Planner", de: "Wochenendplaner"), systemImage: "sun.max.circle.fill")
                        .foregroundStyle(.primary)
                }

                NavigationLink {
                    EventsView()
                } label: {
                    Label(appState.localized(en: "Events", de: "Events"), systemImage: "party.popper.fill")
                        .foregroundStyle(.primary)
                }

                NavigationLink {
                    DealsView()
                } label: {
                    Label(appState.localized(en: "Deals & Free", de: "Angebote & Gratis"), systemImage: "tag.circle.fill")
                        .foregroundStyle(.primary)
                }
            }

            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label(appState.localized(en: "Settings", de: "Einstellungen"), systemImage: "gearshape.circle.fill")
                        .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle(appState.localized(en: "More", de: "Mehr"))
        .navigationBarTitleDisplayMode(.large)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

