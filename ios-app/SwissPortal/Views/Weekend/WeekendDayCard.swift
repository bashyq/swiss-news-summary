import SwiftUI

/// Card for a single weekend day (Saturday or Sunday).
///
/// Displays the day name, date, weather overview (icon + temp range + description),
/// and morning/afternoon planned activities with indoor/outdoor badges and duration.
struct WeekendDayCard: View {
    let day: WeekendDay
    let dayLabel: String
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header with weather
            dayHeader
                .padding(AppSpacing.cardPadding)

            Divider()
                .padding(.horizontal, AppSpacing.cardPadding)

            // Activities
            VStack(alignment: .leading, spacing: 0) {
                // Morning activity
                if let morning = day.plan.morning {
                    activitySection(
                        timeLabel: language == .en ? "Morning" : "Vormittag",
                        timeIcon: "sunrise.fill",
                        activity: morning
                    )
                }

                if day.plan.morning != nil && day.plan.afternoon != nil {
                    Divider()
                        .padding(.horizontal, AppSpacing.cardPadding)
                }

                // Afternoon activity
                if let afternoon = day.plan.afternoon {
                    activitySection(
                        timeLabel: language == .en ? "Afternoon" : "Nachmittag",
                        timeIcon: "sun.max.fill",
                        activity: afternoon
                    )
                }

                // No activities fallback
                if day.plan.morning == nil && day.plan.afternoon == nil {
                    noActivitiesView
                        .padding(AppSpacing.cardPadding)
                }
            }
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, x: AppShadow.subtle.x, y: AppShadow.subtle.y)
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Day name
                Text(dayLabel)
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                // Date
                if let date = DateHelpers.parseISO(day.date) {
                    Text(DateHelpers.display(date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Weather row
            weatherRow
        }
    }

    // MARK: - Weather Row

    @ViewBuilder
    private var weatherRow: some View {
        if let weather = day.weather {
            HStack(spacing: 10) {
                // Weather icon
                Image(systemName: weather.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(weatherIconColor)
                    .frame(width: 32, height: 32)

                // Temperature range
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(Int(weather.tempMax))\u{00B0}")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(weather.tempMin))\u{00B0}")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Weather description
                    Text(weather.localizedDescription(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(10)
            .background(Color.weatherCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Activity Section

    private func activitySection(
        timeLabel: String,
        timeIcon: String,
        activity: PlannedActivity
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time label
            HStack(spacing: 6) {
                Image(systemName: timeIcon)
                    .font(.caption)
                    .foregroundStyle(.znTerracotta)
                Text(timeLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            // Activity name
            Text(activity.localizedName(language: language))
                .font(.subheadline)
                .fontWeight(.semibold)

            // Activity description
            Text(activity.localizedDescription(language: language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Activity badges
            HStack(spacing: 6) {
                // Indoor/Outdoor badge
                BadgeView(
                    text: activity.indoor
                        ? (language == .en ? "Indoor" : "Indoor")
                        : (language == .en ? "Outdoor" : "Outdoor"),
                    icon: activity.indoor ? "house.fill" : "sun.max.fill",
                    color: activity.indoor ? .znNavy : .znTerracotta
                )

                // Duration badge
                if let duration = activity.duration {
                    BadgeView(
                        text: duration,
                        icon: "clock",
                        color: .znMuted
                    )
                }

                // Price badge
                if let price = activity.price {
                    BadgeView(
                        text: price,
                        icon: "banknote",
                        color: .znMuted
                    )
                }
            }
        }
        .padding(AppSpacing.cardPadding)
    }

    // MARK: - No Activities View

    private var noActivitiesView: some View {
        HStack(spacing: 8) {
            Image(systemName: "bed.double.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(language == .en ? "Rest day — no activities planned" : "Ruhetag — keine Aktivitaten geplant")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var weatherIconColor: Color {
        switch day.weather?.weatherCode ?? 3 {
        case 0: return .znTerracotta
        case 1, 2: return .znTerracotta.opacity(0.7)
        case 3: return .znMuted
        case 45, 48: return .znMuted
        case 51...67: return .znNavy
        case 71...77: return .znNavy.opacity(0.7)
        case 80...82: return .znNavy
        case 85, 86: return .znNavy.opacity(0.7)
        case 95...99: return .znNavy.opacity(0.85)
        default: return .znMuted
        }
    }
}

#Preview {
    let sampleDay = WeekendDay(
        date: "2026-02-21",
        weather: DayWeather(
            date: "2026-02-21",
            weatherCode: 1,
            tempMax: 8,
            tempMin: 2,
            description: "Partly cloudy"
        ),
        plan: DayPlan(
            morning: PlannedActivity(
                id: "zoo-zurich",
                name: "Zoo Zurich",
                nameDE: "Zoo Zurich",
                description: "Visit the Masoala Rainforest hall and see the elephants.",
                descriptionDE: "Besuche die Masoala-Regenwaldhalle und sieh die Elefanten.",
                indoor: false,
                duration: "2-4 hours",
                price: "CHF 29"
            ),
            afternoon: PlannedActivity(
                id: "landesmuseum",
                name: "Swiss National Museum",
                nameDE: "Landesmuseum",
                description: "Interactive exhibits about Swiss history and culture.",
                descriptionDE: "Interaktive Ausstellungen uber Schweizer Geschichte und Kultur.",
                indoor: true,
                duration: "1-2 hours",
                price: "Free for kids"
            )
        )
    )

    WeekendDayCard(
        day: sampleDay,
        dayLabel: "Saturday",
        language: .en
    )
    .padding()
}
