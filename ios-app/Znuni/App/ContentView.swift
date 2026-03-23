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
        case .news:
            NewsNavigationStack()
        case .today:
            PlanTabView()
        case .discover:
            DiscoverNavigationStack()
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }
}

// MARK: - News Navigation Stack

private struct NewsNavigationStack: View {
    @Environment(AppState.self) private var appState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            NewsView()
        }
        .onChange(of: appState.tabRetapCount) {
            if appState.selectedTab == .news && !path.isEmpty {
                path = NavigationPath()
            }
        }
    }
}

// MARK: - Plan Tab (implemented in Task 6 — see PlanTabView.swift)

// MARK: - Discover Navigation Stack

/// Manages its own NavigationPath so re-tapping the Discover tab pops to root.
private struct DiscoverNavigationStack: View {
    @Environment(AppState.self) private var appState
    @State private var path = NavigationPath()
    @State private var exploreViewModel = ExploreViewModel()
    @State private var sunshineViewModel = SunshineViewModel()
    @State private var snowViewModel = SnowViewModel()
    @State private var eventsViewModel = EventsViewModel()
    @Environment(LocationManager.self) private var locationManager

    /// Count of upcoming city events (starting within the next 7 days)
    private var upcomingEventCount: Int {
        let now = Date()
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return eventsViewModel.cityEvents.filter { event in
            guard let start = event.startDateParsed else { return false }
            return start >= now && start <= weekFromNow
        }.count
    }

    var body: some View {
        NavigationStack(path: $path) {
            DiscoverView(
                path: $path,
                weather: eventsViewModel.newsData?.weather,
                sunshineDestinations: sunshineViewModel.sunshineData?.destinations,
                snowDestinations: snowViewModel.snowData?.destinations,
                cityEvents: eventsViewModel.cityEvents,
                upcomingEventCount: upcomingEventCount
            )
            .navigationDestination(for: DiscoverRoute.self) { route in
                destinationView(for: route)
            }
            .task {
                // Load all data for discover tab: sunshine, snow, events, and explore (activities for map/categories)
                async let s: () = sunshineViewModel.loadSunshine(language: appState.language)
                async let n: () = snowViewModel.loadSnow(language: appState.language)
                async let e: () = eventsViewModel.loadData(city: appState.city, language: appState.language)
                async let x: () = exploreViewModel.loadData(city: appState.city, language: appState.language)
                _ = await (s, n, e, x)
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
                ZnuniEvent.tabSwitched(to: tab.rawValue)
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
        case .news:
            newspaperIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        case .today:
            gridIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        case .discover:
            mountainIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        case .settings:
            settingsIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        }
    }

    /// Newspaper: folded page with headline and text lines
    private func newspaperIcon(isSelected: Bool, active: Color, inactive: Color) -> some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let scale = s / 22.0
            let lw: CGFloat = 1.5 * scale
            let color = isSelected ? active : inactive

            // Outer page shape with folded left edge
            var page = Path()
            page.move(to: CGPoint(x: 5 * scale, y: 3 * scale))
            page.addLine(to: CGPoint(x: 19 * scale, y: 3 * scale))
            page.addLine(to: CGPoint(x: 19 * scale, y: 19 * scale))
            page.addLine(to: CGPoint(x: 3 * scale, y: 19 * scale))
            page.addLine(to: CGPoint(x: 3 * scale, y: 5 * scale))
            page.closeSubpath()

            // Fold triangle
            var fold = Path()
            fold.move(to: CGPoint(x: 3 * scale, y: 5 * scale))
            fold.addLine(to: CGPoint(x: 5 * scale, y: 5 * scale))
            fold.addLine(to: CGPoint(x: 5 * scale, y: 3 * scale))
            fold.closeSubpath()

            if isSelected {
                context.fill(page, with: .color(color))
                context.fill(fold, with: .color(color.opacity(0.5)))
                // Headline and text lines in background color
                let lineColor = Color.znCream
                let headline = Path(CGRect(x: 7 * scale, y: 7 * scale, width: 9 * scale, height: 2 * scale))
                context.fill(headline, with: .color(lineColor))
                let line1 = Path(CGRect(x: 7 * scale, y: 11.5 * scale, width: 9 * scale, height: 1.2 * scale))
                context.fill(line1, with: .color(lineColor))
                let line2 = Path(CGRect(x: 7 * scale, y: 14.5 * scale, width: 6 * scale, height: 1.2 * scale))
                context.fill(line2, with: .color(lineColor))
            } else {
                context.stroke(page, with: .color(color), lineWidth: lw)
                context.stroke(fold, with: .color(color), lineWidth: lw)
                // Headline and text lines
                let headline = Path(CGRect(x: 7 * scale, y: 7 * scale, width: 9 * scale, height: 2 * scale))
                context.fill(headline, with: .color(color))
                let line1 = Path(CGRect(x: 7 * scale, y: 11.5 * scale, width: 9 * scale, height: 1.2 * scale))
                context.fill(line1, with: .color(color))
                let line2 = Path(CGRect(x: 7 * scale, y: 14.5 * scale, width: 6 * scale, height: 1.2 * scale))
                context.fill(line2, with: .color(color))
            }
        }
    }

    /// Today: 2×2 grid of rounded squares — first filled when selected
    private func gridIcon(isSelected: Bool, active: Color, inactive: Color) -> some View {
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

    /// Settings: Canvas-drawn gear icon — matches line weight of other Canvas icons
    private func settingsIcon(isSelected: Bool, active: Color, inactive: Color) -> some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let scale = s / 22.0
            let lw: CGFloat = 1.5 * scale
            let color = isSelected ? active : inactive
            let center = CGPoint(x: 11 * scale, y: 11 * scale)

            // Inner circle
            let innerR: CGFloat = 3.5 * scale
            let innerPath = Path(ellipseIn: CGRect(
                x: center.x - innerR, y: center.y - innerR,
                width: innerR * 2, height: innerR * 2
            ))

            // Outer circle
            let outerR: CGFloat = 6 * scale
            let outerPath = Path(ellipseIn: CGRect(
                x: center.x - outerR, y: center.y - outerR,
                width: outerR * 2, height: outerR * 2
            ))

            // Gear teeth — 6 small rectangles radiating from center
            var teethPath = Path()
            let toothW: CGFloat = 2.5 * scale
            let toothH: CGFloat = 3 * scale
            let toothR: CGFloat = 7.5 * scale
            for i in 0..<6 {
                let angle = Double(i) * (.pi / 3) - .pi / 2
                let tx = center.x + cos(angle) * toothR - toothW / 2
                let ty = center.y + sin(angle) * toothR - toothH / 2
                let rect = CGRect(x: tx, y: ty, width: toothW, height: toothH)
                let transform = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: angle + .pi / 2)
                    .translatedBy(x: -center.x, y: -center.y)
                teethPath.addRect(rect, transform: transform)
            }

            if isSelected {
                context.fill(outerPath, with: .color(color))
                context.fill(teethPath, with: .color(color))
                context.fill(innerPath, with: .color(Color.znCream))
            } else {
                context.stroke(outerPath, with: .color(color), lineWidth: lw)
                context.stroke(innerPath, with: .color(color), lineWidth: lw)
                context.stroke(teethPath, with: .color(color), lineWidth: lw)
            }
        }
    }
}
