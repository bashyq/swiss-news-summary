import SwiftUI
import CoreLocation

/// The main Activities tab view — "What to do?"
///
/// Displays a filterable, sortable list of family-friendly activities for toddlers.
/// Supports map/list toggle, age filtering, location-based sorting, and a "Surprise me!" feature.
struct ActivitiesView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(ToastManager.self) private var toastManager

    @State private var viewModel = ActivitiesViewModel()
    @State private var surpriseActivity: Activity?
    @State private var showAddSheet = false
    @State private var expandedActivityID: String?

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(appState.city.id)-\(appState.language)") {
                await viewModel.loadActivities(
                    city: appState.city,
                    language: appState.language
                )
            }
            .onChange(of: viewModel.filter) { _, newFilter in
                expandedActivityID = nil
                if newFilter == .nearMe {
                    locationManager.requestLocation()
                }
            }
            .sheet(item: $surpriseActivity) { activity in
                SurpriseMeSheet(
                    activity: activity,
                    onTryAnother: pickSurprise,
                    onSave: {
                        appState.toggleSavedActivity(activity.id)
                        let wasSaved = appState.savedActivityIDs.contains(activity.id)
                        toastManager.show(
                            appState.localized(en: wasSaved ? "Saved" : "Removed", de: wasSaved ? "Gespeichert" : "Entfernt"),
                            type: .success
                        )
                    },
                    isSaved: appState.savedActivityIDs.contains(activity.id)
                )
                .presentationDetents([.fraction(0.7), .large])
            }
            .sheet(isPresented: $showAddSheet) {
                AddActivitySheet()
            }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "What to do?", de: "Was tun?")
    }

    private var mapToggleButton: some View {
        GlassButton(
            systemName: viewModel.showMap ? "list.bullet" : "map"
        ) {
            withAnimation(AppAnimation.standardEase) {
                viewModel.showMap.toggle()
            }
        }
    }

    private var addButton: some View {
        GlassButton(systemName: "plus") {
            showAddSheet = true
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title row + icon buttons
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    // Eyebrow
                    Text(heroEyebrow)
                        .font(.znEyebrow)
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))

                    // Title: "What to _do?_"
                    heroTitle
                }

                Spacer()

                HStack(spacing: 8) {
                    addButton
                    mapToggleButton
                    CityMenuButton()
                }
            }

            // Filter pills inside hero (matching Explore style)
            heroFilterPills
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
                SkylineIllustration()
                    .frame(width: 200, height: 110)
                    .opacity(0.09)
            }
        }
    }

    private var heroEyebrow: String {
        let cityName = appState.city.localizedName(language: appState.language)
        let formatter = DateFormatter()
        formatter.locale = appState.language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE"
        return "\(cityName) · \(formatter.string(from: Date()))"
    }

    private var heroTitle: some View {
        (
            Text(appState.localized(en: "What to ", de: "Was "))
                .font(.bannerTitle)
                .foregroundStyle(.white)
            + Text(appState.localized(en: "do?", de: "tun?"))
                .font(.custom("Playfair", size: 28).italic())
                .foregroundStyle(.white.opacity(0.65))
        )
        .lineLimit(1)
    }

    // MARK: - Hero Filter Pills

    private var heroFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActivityFilter.allCases, id: \.self) { filter in
                    let isSelected = viewModel.filter == filter
                    let label = appState.language == .en ? filter.displayName : filter.displayNameDE
                    let count = filterCount(for: filter)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.filter = filter
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: filter.sfSymbol)
                                .font(.system(size: 11))
                            Text(label)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            if let count, count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(width: 16, height: 16)
                                    .background(.white.opacity(0.25))
                                    .clipShape(Circle())
                            }
                        }
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
            }
        }
    }

    private func filterCount(for filter: ActivityFilter) -> Int? {
        guard let activities = viewModel.activitiesData?.activities else { return nil }
        let count: Int
        switch filter {
        case .all:
            count = activities.filter { !$0.isStayHome }.count
        case .indoor:
            count = activities.filter { $0.indoor && !$0.isStayHome }.count
        case .outdoor:
            count = activities.filter { !$0.indoor && !$0.isStayHome }.count
        case .free:
            count = activities.filter { $0.isFree && !$0.isStayHome }.count
        case .saved:
            // Count only saved IDs that exist in the current city's activities
            let activityIDs = Set(activities.map(\.id))
            count = appState.savedActivityIDs.filter { activityIDs.contains($0) }.count
        case .seasonal:
            count = activities.filter { $0.isCurrentSeason && !$0.isStayHome }.count
        case .stayHome:
            count = activities.filter { $0.isStayHome }.count
        case .nearMe:
            // Count only activities within 2km radius (matching the actual filter)
            if let userLocation = locationManager.location {
                count = activities.filter { activity in
                    guard !activity.isStayHome,
                          let distance = activity.distance(from: userLocation) else { return false }
                    return distance <= 2000
                }.count
            } else {
                count = activities.filter { !$0.isStayHome }.count
            }
        }
        return count > 0 ? count : nil
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.activitiesData == nil {
            ScrollView {
                VStack(spacing: 12) {
                    heroBanner
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonActivityCard()
                    }
                    .padding(.horizontal)
                }
            }
        } else if let error = viewModel.error, viewModel.activitiesData == nil {
            VStack(spacing: 0) {
                heroBanner
                ErrorView(message: error) {
                    Task {
                        await viewModel.loadActivities(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                }
            }
        } else {
            activitiesContent
        }
    }

    private var weatherTintColor: Color? {
        guard let code = viewModel.activitiesData?.weather.weatherCode else { return nil }
        switch code {
        case 0...3: return Color.znTerracotta.opacity(0.03)
        case 51...67, 80...82: return Color.znNavy.opacity(0.03)
        case 71...77, 85, 86: return Color.znMuted.opacity(0.03)
        default: return nil
        }
    }

    // MARK: - Activities Content

    private var activitiesContent: some View {
        let activities = filteredAndSorted

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 0. Hero banner with title + city picker + map/add buttons + filter pills
                heroBanner

                // 1. Results count hint
                HStack {
                    Text(appState.localized(
                        en: "\(activities.count) activities found — tap a card to expand",
                        de: "\(activities.count) Aktivitäten gefunden — tippe zum Öffnen"
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.znMuted)
                    .contentTransition(.numericText())
                    .animation(.default, value: activities.count)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 4)

                // 3. Inline loading indicator for background refresh
                if viewModel.isLoading && viewModel.activitiesData != nil {
                    InlineLoadingView()
                        .padding(.top, 4)
                }

                // 4. Map or list
                if viewModel.showMap {
                    ActivityMapView(
                        activities: activities,
                        city: appState.city,
                        language: appState.language,
                        userFocusLocation: viewModel.filter == .nearMe ? locationManager.location : nil
                    )
                    .padding(.top, 8)
                } else if viewModel.filter == .stayHome {
                    // Stay-home activities get their own grouped layout
                    ScrollView {
                        StayHomeSection(
                            activities: activities,
                            language: appState.language
                        )
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 80) // Space for floating button
                    }
                    .refreshable {
                        await viewModel.loadActivities(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                } else {
                    activityList
                }
            }

            // 5. "Surprise me!" floating button
            surpriseMeButton
                .padding(.bottom, 16)
        }
        .background(weatherTintColor ?? .clear)
    }

    // MARK: - Activity List

    private var activityList: some View {
        let activities = filteredAndSorted

        return Group {
            if activities.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(activities) { activity in
                                ActivityCard(
                                    activity: activity,
                                    language: appState.language,
                                    location: locationManager.location,
                                    expandedID: $expandedActivityID
                                )
                                .id(activity.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 80) // Space for floating button
                    }
                    .refreshable {
                        await viewModel.loadActivities(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                    .onChange(of: expandedActivityID) { _, newID in
                        if let newID {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation {
                                    proxy.scrollTo(newID, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filtered & Sorted Activities

    private var filteredAndSorted: [Activity] {
        var activities = viewModel.filteredActivities(savedIDs: appState.savedActivityIDs)

        // Filter to 2km radius and sort by distance when .nearMe filter is active
        if viewModel.filter == .nearMe, let userLocation = locationManager.location {
            activities = activities.filter { activity in
                guard let distance = activity.distance(from: userLocation) else { return false }
                return distance <= 2000
            }
            activities.sort { a, b in
                let distA = a.distance(from: userLocation) ?? .greatestFiniteMagnitude
                let distB = b.distance(from: userLocation) ?? .greatestFiniteMagnitude
                return distA < distB
            }
        }

        return activities
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            EmojiScene(["🎪", "🧸", "🎨", "🌈", "⭐"])
            Text(appState.localized(
                en: "No activities found",
                de: "Keine Aktivitäten gefunden"
            ))
            .font(.subheadline)
            .foregroundStyle(.znMuted)

            if viewModel.filter == .saved {
                Text(appState.localized(
                    en: "Save activities by tapping the heart icon",
                    de: "Speichere Aktivitäten mit dem Herz-Symbol"
                ))
                .font(.caption)
                .foregroundStyle(.znMuted)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Surprise Me Button

    private var surpriseMeButton: some View {
        Button(action: pickSurprise) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                Text(appState.localized(en: "Surprise me!", de: "Überrasche mich!"))
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.znNavy)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: Color.znNavy.opacity(0.28), radius: 12, x: 0, y: 6)
        }
    }

    private func pickSurprise() {
        let weather = viewModel.activitiesData?.weather
        surpriseActivity = viewModel.surpriseMe(weather: weather, savedIDs: appState.savedActivityIDs)
    }


}

#Preview {
    ActivitiesView()
        .environment(AppState())
        .environment(LocationManager())
        .environment(ToastManager())
}
