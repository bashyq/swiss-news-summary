import SwiftUI
import CoreLocation

/// The main Lunch view — restaurant recommendations with map, list, and "Surprise me!" feature.
///
/// Displays a filterable list (or map) of nearby lunch spots fetched from the worker API.
/// Users can save favorites, rate restaurants, toggle between map/list, and get a random pick.
struct LunchView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager

    @State private var viewModel = LunchViewModel()
    @State private var showSurpriseSheet = false
    @State private var surpriseSpot: LunchSpot?

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    mapToggleButton
                }
            }
            .refreshable {
                await viewModel.loadLunch(
                    city: appState.city,
                    language: appState.language
                )
            }
            .task {
                await viewModel.loadLunch(
                    city: appState.city,
                    language: appState.language
                )
            }
            .onChange(of: appState.city) { _, _ in
                Task {
                    await viewModel.loadLunch(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
            .onChange(of: appState.language) { _, _ in
                Task {
                    await viewModel.loadLunch(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
            .sheet(isPresented: $showSurpriseSheet) {
                if let spot = surpriseSpot {
                    LunchSurpriseSheet(
                        spot: spot,
                        onTryAnother: pickSurprise,
                        onSave: {
                            appState.toggleSavedLunch(spot.id)
                        },
                        isSaved: appState.savedLunchIDs.contains(spot.id)
                    )
                    .presentationDetents([.medium, .large])
                }
            }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "Lunch", de: "Mittagessen")
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.lunchData == nil {
            LoadingView(message: appState.localized(
                en: "Loading restaurants...",
                de: "Restaurants laden..."
            ))
        } else if let error = viewModel.error, viewModel.lunchData == nil {
            ErrorView(message: error) {
                Task {
                    await viewModel.loadLunch(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
        } else {
            lunchContent
        }
    }

    // MARK: - Lunch Content

    private var lunchContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 1. Filter bar
                LunchFilterBar(viewModel: viewModel, language: appState.language)
                    .padding(.top, 8)

                // 2. Inline loading indicator for background refresh
                if viewModel.isLoading && viewModel.lunchData != nil {
                    InlineLoadingView()
                        .padding(.top, 4)
                }

                // 3. Map or list
                if viewModel.showMap {
                    LunchMapView(
                        spots: currentSpots,
                        city: appState.city,
                        language: appState.language
                    )
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // 4. Spot list
                spotList
            }

            // 5. "Surprise me!" floating button
            surpriseMeButton
                .padding(.bottom, 16)
        }
    }

    // MARK: - Spot List

    private var spotList: some View {
        let spots = currentSpots

        return Group {
            if spots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(spots) { spot in
                            LunchCard(
                                spot: spot,
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

    // MARK: - Current Spots

    private var currentSpots: [LunchSpot] {
        var spots = viewModel.filteredSpots(savedIDs: appState.savedLunchIDs)

        // Sort by distance if location is available
        if let userLocation = locationManager.location {
            spots.sort { a, b in
                a.distance(from: userLocation) < b.distance(from: userLocation)
            }
        }

        return spots
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(appState.localized(
                en: "No restaurants found",
                de: "Keine Restaurants gefunden"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if viewModel.filter == .saved {
                Text(appState.localized(
                    en: "Save restaurants by tapping the heart icon",
                    de: "Speichere Restaurants mit dem Herz-Symbol"
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
        if let spot = viewModel.surpriseMe(savedIDs: appState.savedLunchIDs) {
            surpriseSpot = spot
            showSurpriseSheet = true
        }
    }
}

#Preview {
    NavigationStack {
        LunchView()
            .environment(AppState())
            .environment(LocationManager())
    }
}
