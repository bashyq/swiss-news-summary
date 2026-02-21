import SwiftUI

/// The main Events tab view — "What's On"
///
/// Combines a calendar grid with day-detail panels, event filtering,
/// and a scrollable list of all events (holidays, school holidays, festivals,
/// recurring activities, and seasonal activities).
struct EventsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = EventsViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .refreshable {
                    await viewModel.loadData(
                        city: appState.city,
                        language: appState.language
                    )
                }
                .task {
                    await viewModel.loadData(
                        city: appState.city,
                        language: appState.language
                    )
                }
                .onChange(of: appState.city) { _, _ in
                    Task {
                        await viewModel.loadData(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                }
                .onChange(of: appState.language) { _, _ in
                    Task {
                        await viewModel.loadData(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                }
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
            LoadingView(message: appState.localized(
                en: "Loading events...",
                de: "Events laden..."
            ))
        } else if let error = viewModel.error,
                  viewModel.newsData == nil && viewModel.activitiesData == nil {
            ErrorView(message: error) {
                Task {
                    await viewModel.loadData(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
        } else {
            eventsContent
        }
    }

    // MARK: - Events Content

    private var eventsContent: some View {
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

                // 5. Filtered events list
                filteredEventsList
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Filter Bar

    private var eventsFilterBar: some View {
        let filters = ["all", "holidays", "schoolHolidays", "events", "recurring", "seasonal", "festivals"]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(
                        label: filterLabel(for: filter),
                        isSelected: viewModel.eventFilter == filter,
                        icon: filterIcon(for: filter)
                    ) {
                        viewModel.eventFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func filterLabel(for filter: String) -> String {
        switch filter {
        case "all":
            return appState.localized(en: "All", de: "Alle")
        case "holidays":
            return appState.localized(en: "Holidays", de: "Feiertage")
        case "schoolHolidays":
            return appState.localized(en: "School Holidays", de: "Schulferien")
        case "events":
            return appState.localized(en: "Events", de: "Veranstaltungen")
        case "recurring":
            return appState.localized(en: "Recurring", de: "Wiederkehrend")
        case "seasonal":
            return appState.localized(en: "Seasonal", de: "Saisonal")
        case "festivals":
            return appState.localized(en: "Festivals", de: "Festivals")
        default:
            return filter
        }
    }

    private func filterIcon(for filter: String) -> String? {
        switch filter {
        case "all": return "square.grid.2x2"
        case "holidays": return "flag"
        case "schoolHolidays": return "graduationcap"
        case "events": return "star"
        case "recurring": return "arrow.triangle.2.circlepath"
        case "seasonal": return "leaf"
        case "festivals": return "party.popper"
        default: return nil
        }
    }

    // MARK: - Filtered Events List

    private var filteredEventsList: some View {
        let events = viewModel.filteredEvents(language: appState.language)

        return Group {
            if events.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        eventRow(for: event, index: index)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func eventRow(for event: Any, index: Int) -> some View {
        if let holiday = event as? Holiday {
            holidayRow(holiday)
        } else if let schoolHoliday = event as? SchoolHoliday {
            schoolHolidayRow(schoolHoliday)
        } else if let cityEvent = event as? CityEvent {
            EventCard(event: cityEvent)
        } else if let activity = event as? Activity {
            recurringActivityRow(activity)
        }
    }

    // MARK: - Holiday Row

    private func holidayRow(_ holiday: Holiday) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(holiday.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let date = holiday.date {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if holiday.daysUntil >= 0 {
                Text(appState.localized(
                    en: "in \(holiday.daysUntil) days",
                    de: "in \(holiday.daysUntil) Tagen"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - School Holiday Row

    private func schoolHolidayRow(_ schoolHoliday: SchoolHoliday) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(schoolHoliday.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(schoolHoliday.startDate) - \(schoolHoliday.endDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Recurring Activity Row

    private func recurringActivityRow(_ activity: Activity) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(activity.localizedDescription(language: appState.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let schedule = activity.recurring {
                    HStack(spacing: 4) {
                        if let days = schedule.days {
                            Text(days.map { $0.capitalized }.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        if let time = schedule.time {
                            Text(time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if activity.isFree {
                FreeBadge()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(appState.localized(
                en: "No events found",
                de: "Keine Events gefunden"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    EventsView()
        .environment(AppState())
}
