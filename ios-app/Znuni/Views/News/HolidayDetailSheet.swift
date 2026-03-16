import SwiftUI

/// Sheet showing all upcoming Swiss holidays.
///
/// Triggered by tapping the next-holiday row in the News hero banner.
/// Follows the same pattern as WeatherDetailSheet — a compact list
/// with dismiss button and presentation detent.
struct HolidayDetailSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let holidays = SwissHolidayCalculator.upcomingHolidays()

                if holidays.isEmpty {
                    Text(appState.localized(
                        en: "No upcoming holidays",
                        de: "Keine bevorstehenden Feiertage"
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.znSurface)
                } else {
                    ForEach(holidays) { holiday in
                        holidayRow(holiday)
                            .listRowBackground(Color.znSurface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.znCream)
            .navigationTitle(appState.localized(
                en: "Upcoming Holidays",
                de: "Kommende Feiertage"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Holiday Row

    private func holidayRow(_ holiday: Holiday) -> some View {
        HStack(spacing: 12) {
            // Flag + colored circle
            ZStack {
                Circle()
                    .fill(daysColor(holiday.daysUntil).opacity(0.12))
                    .frame(width: 40, height: 40)
                Text("🇨🇭")
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(holiday.localizedName(language: appState.language))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.znInk)

                Text(formattedDate(holiday.date))
                    .font(.system(size: 12))
                    .foregroundStyle(.znMuted)
            }

            Spacer()

            // Days until badge
            Text(daysUntilText(holiday.daysUntil))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(daysColor(holiday.daysUntil))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(daysColor(holiday.daysUntil).opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: - Helpers

    private func daysUntilText(_ days: Int) -> String {
        if days == 0 {
            return appState.localized(en: "Today", de: "Heute")
        } else if days == 1 {
            return appState.localized(en: "Tomorrow", de: "Morgen")
        } else {
            return appState.localized(en: "\(days) days", de: "\(days) Tage")
        }
    }

    private func daysColor(_ days: Int) -> Color {
        if days <= 7 { return .znPositive }
        if days <= 30 { return .znTerracotta }
        return .znMuted
    }

    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let display = DateFormatter()
        display.locale = appState.language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        display.dateFormat = appState.language == .de ? "EEEE, d. MMMM" : "EEEE, d MMMM"
        return display.string(from: date)
    }
}

#Preview {
    HolidayDetailSheet()
        .environment(AppState())
}
