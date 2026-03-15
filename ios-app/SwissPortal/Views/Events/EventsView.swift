import SwiftUI

/// The Events view — "Family Events"
///
/// Presented as a subpage under the Explore tab with a hero header
/// matching the CategoryDetailView design pattern.
/// Combines a calendar grid with day-detail panels, event filtering,
/// and a scrollable list of all events (holidays, school holidays, festivals,
/// recurring activities, and seasonal activities).
struct EventsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EventsViewModel()

    /// When true, shows the hero header with back button (Explore subpage mode).
    /// When false, uses a standard navigation title (More menu mode).
    var showHeroHeader: Bool = false

    var body: some View {
        content
            .navigationTitle(showHeroHeader ? "" : navigationTitle)
            .navigationBarTitleDisplayMode(showHeroHeader ? .inline : .large)
            .toolbar(showHeroHeader ? .hidden : .visible, for: .navigationBar)
            .refreshable {
                await viewModel.loadData(
                    city: appState.city,
                    language: appState.language
                )
            }
            .task(id: "\(appState.city.id)-\(appState.language)") {
                await viewModel.loadData(
                    city: appState.city,
                    language: appState.language
                )
            }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "What's On", de: "Was läuft")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.newsData == nil && viewModel.activitiesData == nil {
            if showHeroHeader {
                VStack(spacing: 0) {
                    heroHeader
                    Spacer()
                    LoadingView(message: appState.localized(
                        en: "Loading events...",
                        de: "Events laden..."
                    ))
                    Spacer()
                }
            } else {
                LoadingView(message: appState.localized(
                    en: "Loading events...",
                    de: "Events laden..."
                ))
            }
        } else if let error = viewModel.error,
                  viewModel.newsData == nil && viewModel.activitiesData == nil {
            if showHeroHeader {
                VStack(spacing: 0) {
                    heroHeader
                    Spacer()
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadData(
                                city: appState.city,
                                language: appState.language
                            )
                        }
                    }
                    Spacer()
                }
            } else {
                ErrorView(message: error) {
                    Task {
                        await viewModel.loadData(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                }
            }
        } else {
            eventsContent
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        let eventCount = viewModel.cityEvents.count
        let cityName = appState.city.localizedName(language: appState.language)

        return VStack(alignment: .leading, spacing: 0) {
            // Back button row + glass action buttons
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

                HStack(spacing: 8) {
                    CityMenuButton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Spacer(minLength: 0)

            // Title content — bottom-left
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.localized(en: "Family", de: "Familie") + " · " + cityName)
                    .font(.znEyebrow)
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))

                Text(appState.localized(en: "Family Events", de: "Familienevents"))
                    .font(.bannerTitle)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Label(
                        appState.localized(en: "\(eventCount) events", de: "\(eventCount) Events"),
                        systemImage: "calendar"
                    )
                    .font(.znEyebrow)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.14))
                    .clipShape(Capsule())
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 150)
        .background {
            ZStack {
                LinearGradient(
                    colors: [.znNavy, .znNavy.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [
                        .black.opacity(0.2),
                        .clear,
                        .black.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    // MARK: - Events Content

    private var eventsContent: some View {
        VStack(spacing: 0) {
            if showHeroHeader {
                heroHeader
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    // 1. Calendar grid
                    CalendarGrid(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // 2. Day detail panel (when a date is selected)
                    if let selectedDate = viewModel.selectedDate {
                        DayDetailView(
                            date: selectedDate,
                            viewModel: viewModel
                        )
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    // 3. Inline loading indicator for background refresh
                    if viewModel.isLoading &&
                        (viewModel.newsData != nil || viewModel.activitiesData != nil) {
                        InlineLoadingView()
                            .padding(.top, 8)
                    }

                    // 4. Filter bar
                    eventsFilterBar
                        .padding(.top, 16)

                    // 4.5 Results count
                    HStack {
                        Text(appState.localized(
                            en: "\(currentFilteredEvents.count) results",
                            de: "\(currentFilteredEvents.count) Ergebnisse"
                        ))
                        .font(.caption)
                        .foregroundStyle(.znMuted)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // 5. Filtered events list
                    filteredEventsList
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var eventsFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EventFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        label: appState.language == .de ? filter.displayNameDE : filter.displayName,
                        isSelected: viewModel.eventFilter == filter,
                        icon: filter.sfSymbol
                    ) {
                        viewModel.eventFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Filtered Events

    private var currentFilteredEvents: [EventItem] {
        viewModel.filteredEvents(language: appState.language)
    }

    // MARK: - Filtered Events List

    private var filteredEventsList: some View {
        let events = currentFilteredEvents

        return Group {
            if events.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(events) { item in
                        eventRow(for: item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func eventRow(for item: EventItem) -> some View {
        switch item {
        case .holiday(let holiday):
            holidayRow(holiday)
        case .schoolHoliday(let schoolHoliday):
            schoolHolidayRow(schoolHoliday)
        case .cityEvent(let cityEvent):
            EventCard(event: cityEvent)
        case .activity(let activity):
            recurringActivityRow(activity)
        }
    }

    // MARK: - Holiday Row

    private func holidayRow(_ holiday: Holiday) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.fill")
                .font(.caption)
                .foregroundStyle(.znNegative)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(holiday.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(holiday.date)
                    .font(.caption)
                    .foregroundStyle(.znMuted)
            }

            Spacer()

            if holiday.daysUntil >= 0 {
                Text(appState.localized(
                    en: "in \(holiday.daysUntil) days",
                    de: "in \(holiday.daysUntil) Tagen"
                ))
                .font(.caption)
                .foregroundStyle(.znMuted)
            }
        }
        .padding(12)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - School Holiday Row

    private func schoolHolidayRow(_ schoolHoliday: SchoolHoliday) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.caption)
                .foregroundStyle(.znTerracotta)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(schoolHoliday.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(schoolHoliday.startDate) - \(schoolHoliday.endDate)")
                    .font(.caption)
                    .foregroundStyle(.znMuted)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Recurring Activity Row

    private func recurringActivityRow(_ activity: Activity) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.znNavy)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(activity.localizedDescription(language: appState.language))
                    .font(.caption)
                    .foregroundStyle(.znMuted)
                    .lineLimit(2)

                if let schedule = activity.recurring {
                    Text(schedule)
                        .font(.caption2)
                        .foregroundStyle(.znNavy)
                }
            }

            Spacer()

            if activity.isFree {
                FreeBadge()
            }
        }
        .padding(12)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(.znMuted)
            Text(appState.localized(
                en: "No events found",
                de: "Keine Events gefunden"
            ))
            .font(.subheadline)
            .foregroundStyle(.znMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview("Hero Mode") {
    NavigationStack {
        EventsView(showHeroHeader: true)
    }
    .environment(AppState())
}

#Preview("Standard") {
    NavigationStack {
        EventsView()
    }
    .environment(AppState())
}
