import SwiftUI

/// Detail panel shown below the calendar for the selected day.
///
/// Displays all events occurring on the selected date:
/// - Purple banner for public holidays
/// - Amber banner for school holidays (with date range)
/// - Festival cards with purple left border
/// - Recurring activity cards
struct DayDetailView: View {
    @Environment(AppState.self) private var appState

    let date: Date
    @Bindable var viewModel: EventsViewModel

    @State private var anchorFormEvent: CityEvent?

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

            if dayEvents.isEmpty {
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


            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .sheet(item: $anchorFormEvent) { event in
            AnchorFormSheet(
                event: event,
                language: appState.language
            ) { anchor in
                AnchorStore.shared.add(anchor)
            }
            .environment(appState)
            .presentationDetents([.large])
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.subheadline)
                .foregroundStyle(.brand)

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
                    .background(Color.brand.opacity(0.15))
                    .foregroundStyle(.brand)
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
        .background(Color.brand)
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
        .background(Color.znTerracotta)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Festival Card

    private func festivalCard(_ festival: CityEvent) -> some View {
        HStack(spacing: 0) {
            // Purple left border
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.brand)
                .frame(width: AppSpacing.borderStripWidth)

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
                Text(festival.localizedDescription(language: appState.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Badges
                HStack(spacing: 6) {
                    if festival.toddlerFriendly {
                        ToddlerFriendlyBadge()
                    }
                    if festival.free {
                        FreeBadge()
                    }
                }

                // "Add to your plan" CTA (only for plannable events on today)
                if isToday && festival.isPlannable {
                    Button {
                        anchorFormEvent = festival
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.caption2)
                            Text(appState.localized(
                                en: "Add to your plan",
                                de: "Zum Plan hinzufügen"
                            ))
                            .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.znNavy)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Color.znNavy.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
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
                        .foregroundStyle(.brand)
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
                .foregroundStyle(.znNavy)
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
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
