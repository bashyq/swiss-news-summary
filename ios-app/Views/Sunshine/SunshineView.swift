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

    var body: some View {
        content
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

    // MARK: - Sunshine Content

    private var sunshineContent: some View {
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
                        onDestinationTapped: { dest in
                            viewModel.toggleExpanded(dest.id)
                            withAnimation {
                                proxy.scrollTo(dest.id, anchor: .center)
                            }
                        }
                    )
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // 6. Destination cards
                    ForEach(filteredDestinations) { destination in
                        SunshineCard(
                            destination: destination,
                            language: appState.language,
                            isExpanded: viewModel.expandedDestinationID == destination.id,
                            userLocation: locationManager.location,
                            highlightID: scrollToID
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.toggleExpanded(destination.id)
                            }
                        }
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
        }
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let fri = formatter.date(from: dates.friday),
              let sun = formatter.date(from: dates.sunday) else {
            return "\(dates.friday) - \(dates.sunday)"
        }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMM"
        displayFormatter.locale = Locale(identifier: appState.language == .de ? "de_CH" : "en_US")
        return "\(displayFormatter.string(from: fri)) - \(displayFormatter.string(from: sun))"
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

            SortPicker(
                options: [
                    (
                        value: SunshineSort.sunshine,
                        label: appState.language == .de ? "Sonne" : "Sun",
                        icon: "sun.max.fill"
                    ),
                    (
                        value: SunshineSort.distance,
                        label: appState.language == .de ? "Nähe" : "Near",
                        icon: "location.fill"
                    )
                ],
                selected: Binding(
                    get: { viewModel.sort },
                    set: { viewModel.sort = $0 }
                )
            )
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

#Preview {
    NavigationStack {
        SunshineView()
            .environment(AppState())
            .environment(LocationManager())
    }
}
