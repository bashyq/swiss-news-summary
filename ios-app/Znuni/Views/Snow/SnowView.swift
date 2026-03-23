import SwiftUI
import CoreLocation

/// Main snow view — weekly snowfall forecasts for Swiss ski resorts.
///
/// Shows an interactive map and ranked card list of resorts sorted by snowfall.
/// Includes a "fresh powder alert" banner when top resort has >40cm, plus filter/sort controls.
struct SnowView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager

    @State private var viewModel = SnowViewModel()
    @State private var showSortSheet = false

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadSnow(language: appState.language)
            }
            .refreshable {
                await viewModel.loadSnow(language: appState.language, forceRefresh: true)
            }
            .onChange(of: appState.language) { _, _ in
                Task {
                    await viewModel.loadSnow(language: appState.language)
                }
            }
            .onChange(of: viewModel.sort) { _, newSort in
                if newSort == .distance && !locationManager.isAuthorized {
                    locationManager.requestLocation()
                }
            }
            .sheet(isPresented: $showSortSheet) {
                SnowSortSheet(
                    selectedSort: $viewModel.sort,
                    language: appState.language
                )
                .presentationDetents([.height(200)])
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.snowData == nil {
            LoadingView(message: appState.localized(
                en: "Loading snow forecast...",
                de: "Schneeprognose laden..."
            ))
        } else if let error = viewModel.error, viewModel.snowData == nil {
            ErrorView(message: error) {
                Task {
                    await viewModel.loadSnow(language: appState.language, forceRefresh: true)
                }
            }
        } else {
            snowContent
        }
    }

    // MARK: - Hero Banner

    @Environment(\.dismiss) private var dismiss

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button row
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.localized(en: "SNOW FORECAST", de: "SCHNEEPROGNOSE"))
                    .font(.znEyebrow)
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))

                (
                    Text(appState.localized(en: "Where's the ", de: "Wo liegt "))
                        .font(.bannerTitle)
                        .foregroundStyle(.white)
                    + Text(appState.localized(en: "snow?", de: "Schnee?"))
                        .font(.custom("Playfair", size: 28).italic())
                        .foregroundStyle(.white.opacity(0.65))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy.ignoresSafeArea(.container, edges: .top)
                // Cool blue glow for snow identity
                RadialGradient(colors: [Color.snowGradientStart.opacity(0.35), .clear],
                               center: UnitPoint(x: 1.0, y: 0.0), startRadius: 0, endRadius: 280)
                SkylineIllustration().frame(width: 200, height: 110).opacity(0.09)
            }
        }
    }

    // MARK: - Snow Content

    private var snowContent: some View {
        VStack(spacing: 0) {
            heroBanner

            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                // 1. Powder alert banner
                if viewModel.hasPowderAlert, let topResort = topResort {
                    PowderAlertBanner(
                        resort: topResort,
                        language: appState.language,
                        onTap: {
                            withAnimation {
                                viewModel.toggleExpanded(topResort.id)
                                proxy.scrollTo(topResort.id, anchor: .top)
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // 2. Week dates header
                if let dates = viewModel.snowData?.weekDates {
                    weekDatesHeader(dates)
                        .padding(.top, 12)
                }

                // 3. Filter bar + sort picker
                filterAndSortBar
                    .padding(.top, 8)

                // 4. Inline loading indicator for background refresh
                if viewModel.isLoading && viewModel.snowData != nil {
                    InlineLoadingView()
                        .padding(.top, 4)
                }

                // 5. Map
                SnowMapView(
                    destinations: filteredDestinations,
                    language: appState.language,
                    userFocusLocation: viewModel.sort == .distance ? locationManager.location : nil,
                    onResortTapped: { resort in
                        withAnimation(AppAnimation.expandEase) {
                            viewModel.toggleExpanded(resort.id)
                        }
                    }
                )
                .frame(height: AppSpacing.mapHeight)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .padding(.horizontal)
                .padding(.top, 12)

                // 6. Resort cards
                ForEach(filteredDestinations) { resort in
                    SnowCard(
                        resort: resort,
                        language: appState.language,
                        isExpanded: viewModel.expandedResortID == resort.id,
                        userLocation: locationManager.location,
                        onTap: {
                            withAnimation(AppAnimation.expandEase) {
                                viewModel.toggleExpanded(resort.id)
                            }
                            if viewModel.expandedResortID == resort.id {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation {
                                        proxy.scrollTo(resort.id, anchor: .top)
                                    }
                                }
                            }
                        },
                        onPlanHere: {
                            if PlanningCity.isCovered(resort.id) {
                                appState.pendingPlanRequest = AppState.PlanRequest(
                                    cityId: resort.id, date: nil
                                )
                            } else {
                                appState.pendingTripRequest = DetectedTrip.synthetic(
                                    locality: resort.name,
                                    coordinate: CLLocationCoordinate2D(latitude: resort.lat, longitude: resort.lon)
                                )
                            }
                            appState.selectedTab = .today
                        }
                    )
                    .id(resort.id)
                    .padding(.horizontal)
                    .padding(.top, 12)
                }

                // 7. Show all button
                let totalCount = allFilteredCount
                ShowAllButton(
                    showAll: $viewModel.showAll,
                    totalCount: totalCount,
                    visibleCount: min(totalCount, 10)
                )
                .padding(.top, 12)
                .padding(.bottom, 24)
                }
            }
            } // ScrollViewReader
        } // VStack
    }

    // MARK: - Week Dates Header

    private func weekDatesHeader(_ dates: WeekDates) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formattedWeekRange(dates))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func formattedWeekRange(_ dates: WeekDates) -> String {
        DateHelpers.formatDateRange(from: dates.monday, to: dates.sunday, language: appState.language)
    }

    // MARK: - Filter & Sort Bar

    private var filterAndSortBar: some View {
        HStack {
            FilterBar(
                filters: SnowFilter.allCases,
                selected: viewModel.filter,
                label: { filter in
                    appState.language == .de ? filter.displayNameDE : filter.displayName
                },
                onSelect: { filter in
                    withAnimation { viewModel.filter = filter }
                }
            )

            Button {
                showSortSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.sort.sfSymbol)
                        .font(.system(size: 10))
                    Text(appState.language == .en
                         ? viewModel.sort.displayName
                         : viewModel.sort.displayNameDE)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.znNavy)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.znNavy.opacity(0.08))
                .clipShape(Capsule())
            }
            .padding(.trailing)
        }
    }

    // MARK: - Data

    private var filteredDestinations: [SnowDestination] {
        viewModel.filteredDestinations(userLocation: locationManager.location)
    }

    /// Top resort by snowfall (for powder alert)
    private var topResort: SnowDestination? {
        viewModel.snowData?.destinations.max(by: { $0.snowfallWeekTotal < $1.snowfallWeekTotal })
    }

    /// Total count of filtered destinations (without the showAll limit)
    private var allFilteredCount: Int {
        guard var destinations = viewModel.snowData?.destinations else { return 0 }

        switch viewModel.filter {
        case .all: break
        case .heavy: destinations = destinations.filter { $0.snowfallWeekTotal > 30 }
        case .moderate: destinations = destinations.filter { $0.snowfallWeekTotal >= 10 && $0.snowfallWeekTotal <= 30 }
        case .light: destinations = destinations.filter { $0.snowfallWeekTotal < 10 }
        }

        return destinations.count
    }
}

// MARK: - Snow Sort Sheet

struct SnowSortSheet: View {
    @Binding var selectedSort: SnowSort
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language == .en ? "Sort by" : "Sortieren nach")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.znInk)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.znMuted)
                        .frame(width: 30, height: 30)
                        .background(Color.znBorder.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Sort options
            ForEach(SnowSort.allCases) { sort in
                Button {
                    selectedSort = sort
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: sort.sfSymbol)
                            .font(.system(size: 14))
                            .foregroundStyle(selectedSort == sort ? .znNavy : .znMuted)
                            .frame(width: 20)

                        Text(language == .en ? sort.displayName : sort.displayNameDE)
                            .font(.system(size: 15))
                            .foregroundStyle(selectedSort == sort ? .znInk : .znBody)

                        Spacer()

                        if selectedSort == sort {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.znNavy)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(selectedSort == sort ? Color.znNavy.opacity(0.06) : .clear)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: selectedSort)
            }

            Spacer()
        }
        .background(Color.znSurface)
    }
}

#Preview {
    NavigationStack {
        SnowView()
            .environment(AppState())
            .environment(LocationManager())
    }
}
