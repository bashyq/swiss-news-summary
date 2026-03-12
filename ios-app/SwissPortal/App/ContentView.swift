import SwiftUI

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
        case .explore:
            ExploreNavigationStack()
        default:
            NavigationStack {
                switch tab {
                case .news: NewsView()
                case .activities: ActivitiesView()
                case .weekend: WeekendTabView()
                case .settings: SettingsView()
                default: EmptyView()
                }
            }
        }
    }
}

// MARK: - Explore Navigation Stack

/// Manages its own NavigationPath so re-tapping the Explore tab pops to root.
private struct ExploreNavigationStack: View {
    @Environment(AppState.self) private var appState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ExploreView(path: $path)
        }
        .onChange(of: appState.tabRetapCount) {
            if appState.selectedTab == .explore && !path.isEmpty {
                path = NavigationPath()
            }
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
        case .news:
            newsIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        case .activities:
            starIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        case .explore:
            mountainIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
        case .weekend:
            personIcon(isSelected: isSelected, active: activeColor, inactive: inactiveColor)
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

    /// Activities: 5-point star — stroked when inactive, filled when selected
    private func starIcon(isSelected: Bool, active: Color, inactive: Color) -> some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let scale = s / 22.0
            let lw: CGFloat = 1.5 * scale
            let color = isSelected ? active : inactive

            // Star path from mockup: M11 2L13.5 8H20L15 12L17 19L11 15L5 19L7 12L2 8H8.5L11 2Z
            var path = Path()
            path.move(to: CGPoint(x: 11 * scale, y: 2 * scale))
            path.addLine(to: CGPoint(x: 13.5 * scale, y: 8 * scale))
            path.addLine(to: CGPoint(x: 20 * scale, y: 8 * scale))
            path.addLine(to: CGPoint(x: 15 * scale, y: 12 * scale))
            path.addLine(to: CGPoint(x: 17 * scale, y: 19 * scale))
            path.addLine(to: CGPoint(x: 11 * scale, y: 15 * scale))
            path.addLine(to: CGPoint(x: 5 * scale, y: 19 * scale))
            path.addLine(to: CGPoint(x: 7 * scale, y: 12 * scale))
            path.addLine(to: CGPoint(x: 2 * scale, y: 8 * scale))
            path.addLine(to: CGPoint(x: 8.5 * scale, y: 8 * scale))
            path.closeSubpath()

            if isSelected {
                context.fill(path, with: .color(color))
            } else {
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
            }
        }
    }

    /// Explore: Mountain landscape — stroked when inactive, filled when selected
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

    /// Weather: Person bust — stroked when inactive, filled when selected
    private func personIcon(isSelected: Bool, active: Color, inactive: Color) -> some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let scale = s / 22.0
            let lw: CGFloat = 1.5 * scale
            let color = isSelected ? active : inactive

            // Head circle: cx=11 cy=8 r=5
            let headCenter = CGPoint(x: 11 * scale, y: 8 * scale)
            let headRadius = 5 * scale
            let headPath = Path(ellipseIn: CGRect(
                x: headCenter.x - headRadius,
                y: headCenter.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            ))

            // Shoulders: M8 13C5 14 3 16 3 18H19C19 16 17 14 14 13
            var shoulderPath = Path()
            shoulderPath.move(to: CGPoint(x: 8 * scale, y: 13 * scale))
            shoulderPath.addCurve(
                to: CGPoint(x: 3 * scale, y: 18 * scale),
                control1: CGPoint(x: 5 * scale, y: 14 * scale),
                control2: CGPoint(x: 3 * scale, y: 16 * scale)
            )
            shoulderPath.addLine(to: CGPoint(x: 19 * scale, y: 18 * scale))
            shoulderPath.addCurve(
                to: CGPoint(x: 14 * scale, y: 13 * scale),
                control1: CGPoint(x: 19 * scale, y: 16 * scale),
                control2: CGPoint(x: 17 * scale, y: 14 * scale)
            )

            if isSelected {
                context.fill(headPath, with: .color(color))
                shoulderPath.closeSubpath()
                context.fill(shoulderPath, with: .color(color))
            } else {
                context.stroke(headPath, with: .color(color), lineWidth: lw)
                context.stroke(shoulderPath, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
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

/// Weekend tab — switches between Sunshine, Snow, and Planner views
struct WeekendTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSegment: WeekendSegment = .sunshine

    enum WeekendSegment: String, CaseIterable {
        case sunshine, snow, planner

        var label: String {
            switch self {
            case .sunshine: return "Sunshine"
            case .snow: return "Snow"
            case .planner: return "Planner"
            }
        }

        var labelDE: String {
            switch self {
            case .sunshine: return "Sonnenschein"
            case .snow: return "Schnee"
            case .planner: return "Planer"
            }
        }

        var sfSymbol: String {
            switch self {
            case .sunshine: return "sun.max.fill"
            case .snow: return "snowflake"
            case .planner: return "calendar"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            weatherHero

            switch selectedSegment {
            case .sunshine:
                SunshineView()
            case .snow:
                SnowView()
            case .planner:
                WeekendView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hero Banner

    private var weatherHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row + glass buttons
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    // Eyebrow
                    Text(weatherEyebrow)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))

                    // Title
                    heroTitle
                }

                Spacer()
            }

            // Segment toggle pills (Explore-style)
            segmentPills
                .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy
                    .ignoresSafeArea(.container, edges: .top)

                RadialGradient(
                    colors: [Color.znTerracotta.opacity(0.22), .clear],
                    center: UnitPoint(x: 1.2, y: -0.3),
                    startRadius: 0,
                    endRadius: 220
                )

                weatherSkyline
                    .frame(width: 200, height: 110)
                    .opacity(0.09)
            }
        }
    }

    // MARK: - Eyebrow

    private var weatherEyebrow: String {
        switch selectedSegment {
        case .sunshine, .snow:
            return appState.localized(en: "FORECAST", de: "PROGNOSE")
        case .planner:
            return appState.localized(en: "PLANNER", de: "PLANER")
        }
    }

    // MARK: - Hero Title

    private var heroTitle: some View {
        Group {
            let italicWord: String = switch selectedSegment {
            case .sunshine: appState.localized(en: "Sunshine", de: "Sonne")
            case .snow: appState.localized(en: "Snow", de: "Schnee")
            case .planner: appState.localized(en: "Planner", de: "Planer")
            }

            (
                Text(appState.localized(en: "Weekend ", de: "Wochenend-"))
                    .font(.custom("Playfair", size: 28))
                    .foregroundStyle(.white)
                + Text(italicWord)
                    .font(.custom("Playfair", size: 28).italic())
                    .foregroundStyle(.white.opacity(0.65))
            )
            .lineLimit(1)
        }
        .contentTransition(.interpolate)
        .animation(.easeInOut(duration: 0.2), value: selectedSegment)
    }

    // MARK: - Segment Pills

    private var segmentPills: some View {
        HStack(spacing: 8) {
            ForEach(WeekendSegment.allCases, id: \.self) { segment in
                let isSelected = selectedSegment == segment
                Button {
                    withAnimation(AppAnimation.spring) {
                        selectedSegment = segment
                    }
                } label: {
                    Label(
                        appState.language == .en ? segment.label : segment.labelDE,
                        systemImage: segment.sfSymbol
                    )
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.white.opacity(0.2) : .clear)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(isSelected ? 0.6 : 0.3), lineWidth: 1)
                    )
                }
                .sensoryFeedback(.selection, trigger: isSelected)
            }

            Spacer()
        }
    }

    // MARK: - Skyline

    private var weatherSkyline: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let white = Color.white
            ctx.fill(Path(CGRect(x: w * 0.05, y: h * 0.36, width: w * 0.09, height: h * 0.64)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.05, y: h * 0.36))
                p.addLine(to: CGPoint(x: w * 0.095, y: h * 0.11))
                p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.36))
                p.closeSubpath()
            }, with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.19, y: h * 0.45, width: w * 0.11, height: h * 0.55)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.19, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.245, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.45))
                p.closeSubpath()
            }, with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.36, y: h * 0.41, width: w * 0.08, height: h * 0.59)), with: .color(white))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.32, y: h * 0.29, width: w * 0.16, height: h * 0.18)), with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.50, y: h * 0.32, width: w * 0.14, height: h * 0.68)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.69, y: h))
                p.addLine(to: CGPoint(x: w * 0.79, y: h * 0.25))
                p.addLine(to: CGPoint(x: w * 0.89, y: h))
                p.closeSubpath()
            }, with: .color(white))
            ctx.fill(Path(CGRect(x: 0, y: h * 0.76, width: w, height: h * 0.13)), with: .color(white.opacity(0.25)))
        }
    }
}

