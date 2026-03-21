import SwiftUI
import CoreLocation

/// Main sunshine view — weekend sunshine forecasts for Swiss destinations.
///
/// Shows an interactive map and ranked card list of destinations sorted by sunshine hours.
/// Includes a "nearest sunny escape" banner when Zurich has poor weather, plus filter/sort controls.
struct SunshineView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager

    @State private var viewModel = SunshineViewModel()
    @State private var scrollToID: String?
    @State private var showSortSheet = false

    var body: some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadSunshine(language: appState.language)
            }
            .refreshable {
                await viewModel.loadSunshine(language: appState.language, forceRefresh: true)
            }
            .onChange(of: appState.language) { _, _ in
                Task {
                    await viewModel.loadSunshine(language: appState.language)
                }
            }
            .onChange(of: viewModel.sort) { _, newSort in
                if newSort == .distance && !locationManager.isAuthorized {
                    locationManager.requestLocation()
                }
            }
            .sheet(isPresented: $showSortSheet) {
                SunshineSortSheet(
                    selectedSort: $viewModel.sort,
                    language: appState.language
                )
                .presentationDetents([.height(200)])
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sunshineData == nil {
            LoadingView(message: appState.localized(
                en: "Loading sunshine forecast...",
                de: "Sonnenscheinprognose laden..."
            ))
        } else if let error = viewModel.error, viewModel.sunshineData == nil {
            ErrorView(message: error) {
                Task {
                    await viewModel.loadSunshine(language: appState.language, forceRefresh: true)
                }
            }
        } else {
            sunshineContent
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
                Text(appState.localized(en: "SUNSHINE FORECAST", de: "SONNENSCHEIN"))
                    .font(.znEyebrow)
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))

                (
                    Text(appState.localized(en: "Where's the ", de: "Wo scheint die "))
                        .font(.bannerTitle)
                        .foregroundStyle(.white)
                    + Text(appState.localized(en: "sun?", de: "Sonne?"))
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
                // Stronger warm glow for sunshine identity
                RadialGradient(colors: [Color.sunshineGradientStart.opacity(0.4), .clear],
                               center: UnitPoint(x: 1.0, y: 0.0), startRadius: 0, endRadius: 280)
                SkylineIllustration().frame(width: 200, height: 110).opacity(0.09)
            }
        }
    }

    // MARK: - Sunshine Content

    private var sunshineContent: some View {
        VStack(spacing: 0) {
            heroBanner

            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 1. Sunny escape banner
                    if let escape = viewModel.nearestSunnyEscape(userLocation: locationManager.location) {
                        SunnyEscapeBanner(
                            destination: escape,
                            language: appState.language
                        ) {
                            scrollToID = escape.id
                            withAnimation {
                                proxy.scrollTo(escape.id, anchor: .center)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // 2. Weekend dates header
                    if let dates = viewModel.sunshineData?.weekendDates {
                        weekendDatesHeader(dates)
                            .padding(.top, 12)
                    }

                    // 3. Filter bar + sort picker
                    filterAndSortBar
                        .padding(.top, 8)

                    // 4. Inline loading indicator for background refresh
                    if viewModel.isLoading && viewModel.sunshineData != nil {
                        InlineLoadingView()
                            .padding(.top, 4)
                    }

                    // 5. Map
                    SunshineMapView(
                        destinations: filteredDestinations,
                        language: appState.language,
                        userFocusLocation: viewModel.sort == .distance ? locationManager.location : nil,
                        onDestinationTapped: { dest in
                            viewModel.toggleExpanded(dest.id)
                            withAnimation {
                                proxy.scrollTo(dest.id, anchor: .center)
                            }
                        }
                    )
                    .frame(height: AppSpacing.mapHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // 6. Destination cards
                    ForEach(filteredDestinations) { destination in
                        SunshineCard(
                            destination: destination,
                            language: appState.language,
                            isExpanded: viewModel.expandedDestinationID == destination.id,
                            userLocation: locationManager.location,
                            highlightID: scrollToID,
                            onTap: {
                                withAnimation(AppAnimation.expandEase) {
                                    viewModel.toggleExpanded(destination.id)
                                }
                                if viewModel.expandedDestinationID == destination.id {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        withAnimation {
                                            proxy.scrollTo(destination.id, anchor: .top)
                                        }
                                    }
                                }
                            },
                            onPlanHere: PlanningCity.isCovered(destination.id) ? {
                                appState.pendingPlanRequest = AppState.PlanRequest(
                                    cityId: destination.id, date: nil
                                )
                                appState.selectedTab = .today
                            } : nil
                        )
                        .id(destination.id)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    // 7. Show all button
                    let totalCount = allFilteredCount
                    ShowAllButton(
                        showAll: $viewModel.showAll,
                        totalCount: totalCount,
                        visibleCount: min(totalCount, 11) // baseline + 10
                    )
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            } // ScrollViewReader
        } // VStack
    }

    // MARK: - Weekend Dates Header

    private func weekendDatesHeader(_ dates: WeekendDates) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formattedWeekendRange(dates))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func formattedWeekendRange(_ dates: WeekendDates) -> String {
        DateHelpers.formatDateRange(from: dates.friday, to: dates.sunday, language: appState.language)
    }

    // MARK: - Filter & Sort Bar

    private var filterAndSortBar: some View {
        HStack {
            FilterBar(
                filters: SunshineFilter.allCases,
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

    // MARK: - Filtered Destinations

    private var filteredDestinations: [SunshineDestination] {
        viewModel.filteredDestinations(userLocation: locationManager.location)
    }

    /// Total count of filtered destinations (without the showAll limit)
    private var allFilteredCount: Int {
        guard let destinations = viewModel.sunshineData?.destinations else { return 0 }
        let baseline = destinations.first { $0.isBaseline == true }
        var rest = destinations.filter { $0.isBaseline != true }

        switch viewModel.filter {
        case .all: break
        case .sunny: rest = rest.filter { $0.sunshineHoursTotal > 6 }
        case .partly: rest = rest.filter { $0.sunshineHoursTotal >= 3 && $0.sunshineHoursTotal <= 6 }
        case .cloudy: rest = rest.filter { $0.sunshineHoursTotal < 3 }
        }

        return (baseline != nil ? 1 : 0) + rest.count
    }
}

// MARK: - Sunshine Sort Sheet

struct SunshineSortSheet: View {
    @Binding var selectedSort: SunshineSort
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
            ForEach(SunshineSort.allCases) { sort in
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
        SunshineView()
            .environment(AppState())
            .environment(LocationManager())
    }
}
