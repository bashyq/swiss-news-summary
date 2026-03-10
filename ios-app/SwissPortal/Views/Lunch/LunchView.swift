import SwiftUI
import CoreLocation

/// The main Lunch view — restaurant recommendations with map, list, and "Surprise me!" feature.
///
/// Displays a filterable list (or map) of nearby lunch spots fetched from the worker API.
/// Users can save favorites, rate restaurants, toggle between map/list, and get a random pick.
struct LunchView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(ToastManager.self) private var toastManager

    @State private var viewModel = LunchViewModel()
    @State private var surpriseSpot: LunchSpot?
    @State private var showAddSheet = false
    @State private var focusedSpot: LunchSpot?

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(appState.city.id)-\(appState.language)") {
                await viewModel.loadLunch(
                    city: appState.city,
                    language: appState.language
                )
            }
            .onChange(of: viewModel.activeToggles) { _, newToggles in
                if newToggles.contains(.nearMe) {
                    locationManager.requestLocation()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddRestaurantSheet()
            }
            .sheet(item: $surpriseSpot) { spot in
                LunchSurpriseSheet(
                    spot: spot,
                    onTryAnother: pickSurprise,
                    onSave: {
                        appState.toggleSavedLunch(spot.id)
                        let wasSaved = appState.savedLunchIDs.contains(spot.id)
                        toastManager.show(
                            appState.localized(en: wasSaved ? "Saved" : "Removed", de: wasSaved ? "Gespeichert" : "Entfernt"),
                            type: .success
                        )
                    },
                    isSaved: appState.savedLunchIDs.contains(spot.id)
                )
                .presentationDetents([.medium, .large])
            }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "Lunch", de: "Mittagessen")
    }

    // MARK: - City Menu Button

    private var cityMenuButton: some View {
        Menu {
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
        } label: {
            Image(systemName: "building.2")
        }
    }

    // MARK: - Toolbar Buttons

    private var mapToggleButton: some View {
        Button {
            withAnimation(AppAnimation.standardEase) {
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

    // MARK: - Hero Banner

    private var heroBanner: some View {
        HeroBanner(style: .lunch, title: navigationTitle) {
            HStack(spacing: 14) {
                addButton
                mapToggleButton
                cityMenuButton
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.lunchData == nil {
            ScrollView {
                VStack(spacing: 12) {
                    heroBanner
                        .padding(.horizontal)
                        .padding(.top, 8)
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonLunchCard()
                    }
                    .padding(.horizontal)
                }
            }
        } else if let error = viewModel.error, viewModel.lunchData == nil {
            VStack(spacing: 0) {
                heroBanner
                    .padding(.horizontal)
                    .padding(.top, 8)
                ErrorView(message: error) {
                    Task {
                        await viewModel.loadLunch(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                }
            }
        } else {
            lunchContent
        }
    }

    // MARK: - Lunch Content

    private var lunchContent: some View {
        let spots = currentSpots

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 0. Hero banner with title + city picker + map/add buttons
                heroBanner
                    .padding(.horizontal)
                    .padding(.top, 8)

                // 1. Filter bar
                LunchFilterBar(viewModel: viewModel, language: appState.language, savedIDs: appState.savedLunchIDs)
                    .padding(.top, 8)

                // 1.5 Results count
                HStack {
                    let total = spots.count
                    let displayed = viewModel.displaySpots(from: spots).count
                    if displayed < total {
                        Text(appState.localized(
                            en: "\(displayed) of \(total) results",
                            de: "\(displayed) von \(total) Ergebnisse"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: total)
                    } else {
                        Text(appState.localized(
                            en: "\(total) results",
                            de: "\(total) Ergebnisse"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: total)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // 2. Inline loading indicator for background refresh
                if viewModel.isLoading && viewModel.lunchData != nil {
                    InlineLoadingView()
                        .padding(.top, 4)
                }

                // 3. Map or list
                if viewModel.showMap {
                    LunchMapView(
                        spots: spots,
                        city: appState.city,
                        language: appState.language,
                        userFocusLocation: viewModel.activeToggles.contains(.nearMe) ? locationManager.location : nil,
                        focusedSpot: $focusedSpot
                    )
                    .frame(height: AppSpacing.mapHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
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
        let allSpots = currentSpots
        let displayedSpots = viewModel.displaySpots(from: allSpots)
        let isTruncated = displayedSpots.count < allSpots.count

        return Group {
            if allSpots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayedSpots) { spot in
                            LunchCard(
                                spot: spot,
                                language: appState.language,
                                location: locationManager.location,
                                onTap: {
                                    withAnimation(AppAnimation.standardEase) {
                                        viewModel.showMap = true
                                    }
                                    focusedSpot = spot
                                }
                            )
                        }

                        if isTruncated {
                            Button {
                                viewModel.showingAll = true
                            } label: {
                                Text(appState.localized(
                                    en: "Show all \(allSpots.count) restaurants",
                                    de: "Alle \(allSpots.count) Restaurants anzeigen"
                                ))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.brand)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.brand.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                            }
                            .buttonStyle(.plain)
                        }

                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 80) // Space for floating button
                }
                .refreshable {
                    await viewModel.loadLunch(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
        }
    }

    // MARK: - Current Spots

    private var currentSpots: [LunchSpot] {
        var spots = viewModel.filteredSpots(
            savedIDs: appState.savedLunchIDs,
            userLocation: locationManager.location
        )

        // Sort by distance when "Near Me" toggle is active
        if viewModel.activeToggles.contains(.nearMe), let userLocation = locationManager.location {
            spots.sort { a, b in
                a.distance(from: userLocation) < b.distance(from: userLocation)
            }
        }

        return spots
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            EmojiScene(["🍽️", "🧀", "🫕", "🍫", "🥐"])
            Text(appState.localized(
                en: "No restaurants found",
                de: "Keine Restaurants gefunden"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if viewModel.activeToggles.contains(.saved) {
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
            .background(LinearGradient.brand)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: .brand.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private func pickSurprise() {
        surpriseSpot = viewModel.surpriseMe(savedIDs: appState.savedLunchIDs)
    }
}

#Preview {
    NavigationStack {
        LunchView()
            .environment(AppState())
            .environment(LocationManager())
            .environment(ToastManager())
    }
}
