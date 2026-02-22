import SwiftUI
import CoreLocation

/// The main Activities tab view — "What to do?"
///
/// Displays a filterable, sortable list of family-friendly activities for toddlers.
/// Supports map/list toggle, age filtering, location-based sorting, and a "Surprise me!" feature.
struct ActivitiesView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager

    @State private var viewModel = ActivitiesViewModel()
    @State private var showSurpriseSheet = false
    @State private var surpriseActivity: Activity?
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            mapToggleButton
                            addButton
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadActivities(
                        city: appState.city,
                        language: appState.language
                    )
                }
                .task {
                    await viewModel.loadActivities(
                        city: appState.city,
                        language: appState.language
                    )
                }
                .onChange(of: appState.city) { _, _ in
                    Task {
                        await viewModel.loadActivities(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                }
                .onChange(of: appState.language) { _, _ in
                    Task {
                        await viewModel.loadActivities(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                }
                .onChange(of: viewModel.filter) { _, newFilter in
                    if newFilter == .nearMe {
                        locationManager.requestLocation()
                    }
                }
                .sheet(isPresented: $showSurpriseSheet) {
                    if let activity = surpriseActivity {
                        SurpriseMeSheet(
                            activity: activity,
                            onTryAnother: pickSurprise,
                            onSave: {
                                appState.toggleSavedActivity(activity.id)
                            },
                            isSaved: appState.savedActivityIDs.contains(activity.id)
                        )
                        .presentationDetents([.medium, .large])
                    }
                }
                .sheet(isPresented: $showAddSheet) {
                    AddActivitySheet()
                }
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
            LoadingView(message: appState.localized(
                en: "Loading activities...",
                de: "Aktivitäten laden..."
            ))
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

    // MARK: - Activities Content

    private var activitiesContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 1. Filter bar
                ActivityFilterBar(viewModel: viewModel, language: appState.language)
                    .padding(.top, 8)

                // 2. Age filter picker
                AgeFilterPicker(viewModel: viewModel, language: appState.language)
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
                        activities: filteredAndSorted,
                        city: appState.city,
                        language: appState.language
                    )
                    .padding(.top, 8)
                } else if viewModel.filter == .stayHome {
                    // Stay-home activities get their own grouped layout
                    ScrollView {
                        StayHomeSection(
                            activities: filteredAndSorted,
                            language: appState.language
                        )
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 80) // Space for floating button
                    }
                } else {
                    activityList
                }
            }

            // 5. "Surprise me!" floating button
            surpriseMeButton
                .padding(.bottom, 16)
        }
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
            Image(systemName: "figure.play")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
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
            .background(Color.purple)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private func pickSurprise() {
        let weather = viewModel.activitiesData?.weather
        if let activity = viewModel.surpriseMe(weather: weather, savedIDs: appState.savedActivityIDs) {
            surpriseActivity = activity
            showSurpriseSheet = true
        }
    }
}

#Preview {
    ActivitiesView()
        .environment(AppState())
        .environment(LocationManager())
}
