import SwiftUI

// MARK: - Discover Route

enum DiscoverRoute: Hashable {
    case sunshine
    case snow
    case events
    case activities
    case restaurants
    case museums
    case parks
    case deals
    case map
}

/// Root view with custom static tab bar matching Znüni design mockup
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            // Content area — each tab in its own NavigationStack, preserved across switches
            ZStack {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    tabContent(tab)
                        .opacity(state.selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(state.selectedTab == tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom static tab bar
            ZnuniTabBar(selectedTab: $state.selectedTab)
        }
        .overlay(alignment: .bottom) {
            ToastOverlay()
                .padding(.bottom, 90)
        }
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .today:
            TodayNavigationStack()
        case .discover:
            DiscoverNavigationStack()
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }
}

// MARK: - Today Navigation Stack

/// Manages its own NavigationPath so "See all news →" can push NewsView.
private struct TodayNavigationStack: View {
    @Environment(AppState.self) private var appState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            TodayView()
        }
        .onChange(of: appState.tabRetapCount) {
            if appState.selectedTab == .today && !path.isEmpty {
                path = NavigationPath()
            }
        }
    }
}

// MARK: - Discover Navigation Stack

/// Manages its own NavigationPath so re-tapping the Discover tab pops to root.
private struct DiscoverNavigationStack: View {
    @Environment(AppState.self) private var appState
    @State private var path = NavigationPath()
    @State private var exploreViewModel = ExploreViewModel()
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        NavigationStack(path: $path) {
            DiscoverView(path: $path)
                .navigationDestination(for: DiscoverRoute.self) { route in
                    destinationView(for: route)
                }
        }
        .onChange(of: appState.tabRetapCount) {
            if appState.selectedTab == .discover && !path.isEmpty {
                path = NavigationPath()
            }
        }
        .onChange(of: appState.pendingDiscoverRoute) { _, route in
            if let route {
                switch route {
                case "lunch", "restaurants":
                    path.append(DiscoverRoute.restaurants)
                case "events":
                    path.append(DiscoverRoute.events)
                case "activities":
                    path.append(DiscoverRoute.activities)
                case "sunshine":
                    path.append(DiscoverRoute.sunshine)
                case "snow":
                    path.append(DiscoverRoute.snow)
                default:
                    break
                }
                appState.pendingDiscoverRoute = nil
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: DiscoverRoute) -> some View {
        switch route {
        case .sunshine:
            SunshineView()
        case .snow:
            SnowView()
        case .events:
            EventsView(showHeroHeader: true)
        case .activities:
            ActivitiesView()
        case .restaurants:
            LunchView()
        case .museums:
            CategoryDetailView(
                category: .museums,
                viewModel: exploreViewModel,
                userLocation: locationManager.location
            )
        case .parks:
            CategoryDetailView(
                category: .parks,
                viewModel: exploreViewModel,
                userLocation: locationManager.location
            )
        case .deals:
            // Placeholder until DealsView is created as a standalone view
            Text("Deals")
                .font(.title)
                .foregroundStyle(.znMuted)
        case .map:
            ExploreMapOverlay(
                items: exploreViewModel.filteredItems(
                    city: appState.city,
                    language: appState.language
                ),
                city: appState.city,
                onCollapse: {
                    if !path.isEmpty {
                        path.removeLast()
                    }
                }
            )
        }
    }
}

// MARK: - Custom Tab Bar

/// Static footer tab bar matching the Znüni design mockup:
/// cream background with blur, border-top, custom SVG-style icons
struct ZnuniTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.znBorder)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            if selectedTab != tab {
                selectedTab = tab
            } else {
                appState.tabRetapCount += 1
            }
        } label: {
            VStack(spacing: 3) {
                tabIcon(tab, isSelected: selectedTab == tab)
                    .frame(width: 22, height: 22)

                Text(appState.language == .en ? tab.label : tab.labelDE)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selectedTab == tab ? Color.znNavy : Color.znMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.language == .en ? tab.label : tab.labelDE)
    }

    // MARK: - Tab Icons (matching mockup SVGs)

    @ViewBuilder
    private func tabIcon(_ tab: AppTab, isSelected: Bool) -> some View {
        let activeColor = Color.znNavy
        let inactiveColor = Color.znMuted

        switch tab {
        case .today:
            newsIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        case .discover:
            mountainIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        case .settings:
            settingsIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        }
    }

    /// News: 2×2 grid of rounded squares — first filled when selected
    private func newsIcon(isSelected: Bool, active: Color, inactive: Color) -> some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let scale = s / 22.0
            let rects: [(CGFloat, CGFloat)] = [(2, 2), (12, 2), (2, 12), (12, 12)]
            let w: CGFloat = 8 * scale
            let rx: CGFloat = 2 * scale
            let lw: CGFloat = 1.5 * scale
            let color = isSelected ? active : inactive

            for (i, origin) in rects.enumerated() {
                let rect = CGRect(x: origin.0 * scale, y: origin.1 * scale, width: w, height: w)
                let path = Path(roundedRect: rect, cornerRadius: rx)

                if isSelected && i == 0 {
                    context.fill(path, with: .color(color))
                } else {
                    context.stroke(path, with: .color(color), lineWidth: lw)
                }
            }
        }
    }

    /// Discover: Mountain landscape — stroked when inactive, filled when selected
    private func mountainIcon(isSelected: Bool, active: Color, inactive: Color) -> some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let scale = s / 22.0
            let lw: CGFloat = 1.5 * scale
            let color = isSelected ? active : inactive

            // Mountain path from mockup: M3 17L8 7L13 12L17 6L20 17H3Z
            var path = Path()
            path.move(to: CGPoint(x: 3 * scale, y: 17 * scale))
            path.addLine(to: CGPoint(x: 8 * scale, y: 7 * scale))
            path.addLine(to: CGPoint(x: 13 * scale, y: 12 * scale))
            path.addLine(to: CGPoint(x: 17 * scale, y: 6 * scale))
            path.addLine(to: CGPoint(x: 20 * scale, y: 17 * scale))
            path.closeSubpath()

            if isSelected {
                context.fill(path, with: .color(color))
            } else {
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
            }
        }
    }

    /// Settings: Gear icon — stroked when inactive, filled when selected
    private func settingsIcon(isSelected: Bool, active: Color, inactive: Color) -> some View {
        let symbolName = isSelected ? "gearshape.fill" : "gearshape"
        let color = isSelected ? active : inactive

        return Image(systemName: symbolName)
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(color)
    }
}
