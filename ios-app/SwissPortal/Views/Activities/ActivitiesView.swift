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

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbarTitleMenu {
                ForEach(City.allCases) { city in
                    Button {
                        appState.city = city
                    } label: {
                        HStack {
                            Text(city.localizedName(language: appState.language))
                            if city == appState.city {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        mapToggleButton
                        addButton
                    }
                }
            }
            .task(id: "\(appState.city.id)-\(appState.language)") {
                await viewModel.loadActivities(
                    city: appState.city,
                    language: appState.language
                )
            }
            .onChange(of: viewModel.filter) { _, newFilter in
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
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAddSheet) {
                AddActivitySheet()
            }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "What to do?", de: "Was tun?")
    }

    // MARK: - Toolbar Buttons

    private var mapToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.showMap.toggle()
            }
        } label: {
            Image(systemName: viewModel.showMap ? "list.bullet" : "map")
        }
    }

    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.activitiesData == nil {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonActivityCard()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
        } else if let error = viewModel.error, viewModel.activitiesData == nil {
            ErrorView(message: error) {
                Task {
                    await viewModel.loadActivities(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
        } else {
            activitiesContent
        }
    }

    private var weatherTintColor: Color? {
        guard let code = viewModel.activitiesData?.weather.weatherCode else { return nil }
        switch code {
        case 0...3: return Color.orange.opacity(0.03)
        case 51...67, 80...82: return Color.blue.opacity(0.03)
        case 71...77, 85, 86: return Color.gray.opacity(0.03)
        default: return nil
        }
    }

    // MARK: - Activities Content

    private var activitiesContent: some View {
        let activities = filteredAndSorted

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 0. Hero banner
                HeroBanner(style: .activities)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // 1. Filter bar
                ActivityFilterBar(viewModel: viewModel, language: appState.language)
                    .padding(.top, 8)

                // 2. Find playgrounds / restaurants
                findNearbyButtons
                    .padding(.horizontal)
                    .padding(.top, 8)

                // 2.6 Results count
                HStack {
                    Text(appState.localized(
                        en: "\(activities.count) results",
                        de: "\(activities.count) Ergebnisse"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.default, value: activities.count)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

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
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(activities) { activity in
                            ActivityCard(
                                activity: activity,
                                language: appState.language,
                                location: locationManager.location
                            )
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
            }
        }
    }

    // MARK: - Filtered & Sorted Activities

    private var filteredAndSorted: [Activity] {
        var activities = viewModel.filteredActivities(savedIDs: appState.savedActivityIDs)

        // Sort by distance when .nearMe filter is active and location is available
        if viewModel.filter == .nearMe, let userLocation = locationManager.location {
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
            .foregroundStyle(.secondary)

            if viewModel.filter == .saved {
                Text(appState.localized(
                    en: "Save activities by tapping the heart icon",
                    de: "Speichere Aktivitäten mit dem Herz-Symbol"
                ))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Surprise Me Button

    private var surpriseMeButton: some View {
        Button(action: pickSurprise) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(appState.localized(en: "Surprise me!", de: "Überrasche mich!"))
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(LinearGradient.brand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: .brand.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private func pickSurprise() {
        let weather = viewModel.activitiesData?.weather
        surpriseActivity = viewModel.surpriseMe(weather: weather, savedIDs: appState.savedActivityIDs)
    }

    // MARK: - Find Nearby Buttons

    private var findNearbyButtons: some View {
        HStack(spacing: 8) {
            Button {
                searchNearby(query: "playground", city: appState.city)
            } label: {
                Label(
                    appState.localized(en: "Find playgrounds", de: "Spielplätze"),
                    systemImage: "figure.play"
                )
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .foregroundStyle(.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                searchNearby(query: "restaurant", city: appState.city)
            } label: {
                Label(
                    appState.localized(en: "Find restaurants", de: "Restaurants"),
                    systemImage: "fork.knife"
                )
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .foregroundStyle(.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func searchNearby(query: String, city: City) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let coord = city.coordinate
        let urlString = "maps://?q=\(encoded)&sll=\(coord.latitude),\(coord.longitude)&z=14"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ActivitiesView()
        .environment(AppState())
        .environment(LocationManager())
        .environment(ToastManager())
}
