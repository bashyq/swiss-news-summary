import SwiftUI

/// Detail panel shown below the calendar for the selected day.
///
/// Displays all events occurring on the selected date:
/// - Purple banner for public holidays
/// - Amber banner for school holidays (with date range)
/// - Festival cards with purple left border
/// - Recurring activity cards
/// - Weather-based activity suggestion (today only)
/// - Trending news topic (today only)
struct DayDetailView: View {
    @Environment(AppState.self) private var appState

    let date: Date
    @Bindable var viewModel: EventsViewModel

    private var dayEvents: DayEvents {
        viewModel.eventsForDate(date)
    }

    private var isToday: Bool {
        DateHelpers.isToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date header
            dateHeader

            if dayEvents.isEmpty && !isToday {
                emptyDayMessage
            } else {
                // Holiday banners
                ForEach(dayEvents.holidays) { holiday in
                    holidayBanner(holiday)
                }

                // School holiday banners
                ForEach(dayEvents.schoolHolidays) { schoolHoliday in
                    schoolHolidayBanner(schoolHoliday)
                }

                // Festival cards
                ForEach(dayEvents.festivals) { festival in
                    festivalCard(festival)
                }

                // Recurring activity cards
                ForEach(dayEvents.recurringActivities) { activity in
                    recurringActivityCard(activity)
                }

                // Today-only sections
                if isToday {
                    // Weather-based activity suggestion
                    weatherSuggestion

                    // Trending topic
                    trendingTopic
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.subheadline)
                .foregroundStyle(.purple)

            Text(formattedDate)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            if isToday {
                Text(appState.localized(en: "Today", de: "Heute"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }
        }
    }

    private var formattedDate: String {
        let dayName = DateHelpers.dayName(date)
        let display = DateHelpers.display(date)
        return "\(dayName), \(display)"
    }

    // MARK: - Empty State

    private var emptyDayMessage: some View {
        HStack {
            Spacer()
            Text(appState.localized(
                en: "No events on this day",
                de: "Keine Events an diesem Tag"
            ))
            .font(.caption)
            .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Holiday Banner

    private func holidayBanner(_ holiday: Holiday) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.fill")
                .font(.caption)
                .foregroundStyle(.white)

            Text(holiday.localizedName(language: appState.language))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(10)
        .background(Color.purple)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - School Holiday Banner

    private func schoolHolidayBanner(_ schoolHoliday: SchoolHoliday) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .font(.caption)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(schoolHoliday.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("\(schoolHoliday.startDate) - \(schoolHoliday.endDate)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()
        }
        .padding(10)
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Festival Card

    private func festivalCard(_ festival: CityEvent) -> some View {
        HStack(spacing: 0) {
            // Purple left border
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.purple)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(festival.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Date range
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(festival.startDate) - \(festival.endDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Description
                if let description = festival.localizedDescription(language: appState.language) {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Badges
                HStack(spacing: 6) {
                    if festival.toddlerFriendly == true {
                        ToddlerFriendlyBadge()
                    }
                    if festival.free == true {
                        FreeBadge()
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.vertical, 8)

            Spacer()

            // Open URL button
            if let urlString = festival.url, let url = URL(string: urlString) {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
            }
        }
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Recurring Activity Card

    private func recurringActivityCard(_ activity: Activity) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.localizedName(language: appState.language))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(activity.localizedDescription(language: appState.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let schedule = activity.recurring {
                    HStack(spacing: 4) {
                        if let time = schedule.time {
                            Text(time)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        if let frequency = schedule.frequency {
                            Text(frequency.capitalized)
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
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Weather Suggestion (Today Only)

    @ViewBuilder
    private var weatherSuggestion: some View {
        if let weather = viewModel.newsData?.weather {
            HStack(spacing: 10) {
                Image(systemName: weather.sfSymbol)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.localized(
                        en: "Weather today",
                        de: "Wetter heute"
                    ))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                    Text("\(Int(weather.temperature))\u{00B0}C - \(weather.description)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(weather.isBadWeather
                        ? appState.localized(
                            en: "Indoor activities recommended",
                            de: "Indoor-Aktivitäten empfohlen"
                        )
                        : appState.localized(
                            en: "Great day for outdoor activities!",
                            de: "Toller Tag für Outdoor-Aktivitäten!"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(weather.isBadWeather ? .blue : .green)
                }

                Spacer()
            }
            .padding(10)
            .background(Color.weatherCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Trending Topic (Today Only)

    @ViewBuilder
    private var trendingTopic: some View {
        if let trending = viewModel.newsData?.trending,
           let topic = trending.localizedTopic(language: appState.language) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.localized(
                        en: "Trending",
                        de: "Im Trend"
                    ))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                    Text(topic)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    ScrollView {
        DayDetailView(
            date: Date(),
            viewModel: EventsViewModel()
        )
        .padding()
    }
    .environment(AppState())
}
