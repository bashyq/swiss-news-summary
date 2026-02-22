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

    var body: some View {
        content
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

    // MARK: - Snow Content

    private var snowContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 1. Powder alert banner
                if viewModel.hasPowderAlert, let topResort = topResort {
                    PowderAlertBanner(
                        resort: topResort,
                        language: appState.language
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
                    onResortTapped: { resort in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.toggleExpanded(resort.id)
                        }
                    }
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 12)

                // 6. Resort cards
                ForEach(filteredDestinations) { resort in
                    SnowCard(
                        resort: resort,
                        language: appState.language,
                        isExpanded: viewModel.expandedResortID == resort.id,
                        userLocation: locationManager.location
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.toggleExpanded(resort.id)
                        }
                    }
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let mon = formatter.date(from: dates.monday),
              let sun = formatter.date(from: dates.sunday) else {
            return "\(dates.monday) - \(dates.sunday)"
        }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMM"
        displayFormatter.locale = Locale(identifier: appState.language == .de ? "de_CH" : "en_US")
        return "\(displayFormatter.string(from: mon)) - \(displayFormatter.string(from: sun))"
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

            SortPicker(
                options: [
                    (
                        value: SnowSort.snowfall,
                        label: appState.language == .de ? "Schnee" : "Snow",
                        icon: "snowflake"
                    ),
                    (
                        value: SnowSort.distance,
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

#Preview {
    NavigationStack {
        SnowView()
            .environment(AppState())
            .environment(LocationManager())
    }
}
