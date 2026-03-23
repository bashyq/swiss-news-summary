import SwiftUI

/// Full-width navy gradient hero for the News tab.
///
/// Edge-to-edge layout matching the Znüni design mockup — eyebrow date,
/// "Today in / _Zürich_" title, weather row with large temp, desc, H/L,
/// and weather icon. Skyline silhouette at bottom-right (9% opacity).
struct NewsHeroBanner: View {
    @Environment(AppState.self) private var appState

    let weather: Weather?
    let onWeatherTap: () -> Void
    var onHolidayTap: (() -> Void)?

    var body: some View {
        // Content drives the size; background layers are overlaid
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow + city selector row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    // Eyebrow date
                    Text(eyebrowDate)
                        .font(.znEyebrow)
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))

                    // Title: "Today in" / "Zürich" (italic)
                    titleText
                }

                Spacer()

                CityMenuButton()
            }
            .padding(.bottom, 18)

            // Weather row
            if let weather {
                Button(action: onWeatherTap) {
                    weatherRow(weather)
                }
                .buttonStyle(.plain)
            }

            // Next holiday row
            if let nextHoliday = SwissHolidayCalculator.upcomingHolidays().first {
                Button {
                    onHolidayTap?()
                } label: {
                    nextHolidayRow(nextHoliday)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy
                    .ignoresSafeArea(.container, edges: .top)

                // Subtle warm glow (top-right)
                RadialGradient(
                    colors: [Color.znTerracotta.opacity(0.22), .clear],
                    center: UnitPoint(x: 1.2, y: -0.3),
                    startRadius: 0,
                    endRadius: 220
                )

                // Skyline silhouette (bottom-right, 9% opacity)
                SkylineIllustration()
                    .frame(width: 200, height: 110)
                    .opacity(0.09)
            }
        }
    }

    // MARK: - Eyebrow Date

    private var eyebrowDate: String {
        let formatter = DateFormatter()
        formatter.locale = appState.language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        formatter.dateFormat = appState.language == .de ? "EEEE · d. MMMM" : "EEEE · d MMMM"
        return formatter.string(from: Date())
    }

    // MARK: - Title

    private var titleText: some View {
        let cityName = appState.city.localizedName(language: appState.language)

        return HStack(spacing: 6) {
            Text(appState.localized(en: "Today in", de: "Heute in"))
                .font(.heroTitle)
                .foregroundStyle(.white)
            Text(cityName)
                .font(.custom("Playfair", size: 30).italic())
                .foregroundStyle(.white.opacity(0.68))
        }
    }

    // MARK: - Weather Row

    private func weatherRow(_ weather: Weather) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Current temperature — large
            Text("\(Int(weather.temperature))°")
                .font(.heroTemperature)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                // Description
                Text(weather.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))

                // H / L
                if let high = weather.highTemp, let low = weather.lowTemp {
                    Text("H: \(Int(high))°  ·  L: \(Int(low))°")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            Spacer()

            // Weather icon on far right
            Image(systemName: weather.sfSymbol)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.yellow)
                .font(.system(size: 36))
        }
    }

    // MARK: - Next Holiday Row

    private func nextHolidayRow(_ holiday: Holiday) -> some View {
        HStack(spacing: 8) {
            Text("🇨🇭")
                .font(.system(size: 13))

            Text(holiday.localizedName(language: appState.language))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Text("·")
                .foregroundStyle(.white.opacity(0.3))

            Text(daysUntilText(holiday.daysUntil))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.znTerracotta.opacity(0.9))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.07))
        .clipShape(Capsule())
    }

    private func daysUntilText(_ days: Int) -> String {
        if days == 0 {
            return appState.localized(en: "Today", de: "Heute")
        } else if days == 1 {
            return appState.localized(en: "Tomorrow", de: "Morgen")
        } else {
            return appState.localized(en: "in \(days) days", de: "in \(days) Tagen")
        }
    }

    // MARK: - Skyline Illustration

}

#Preview {
    let weather = Weather(
        temperature: 15,
        description: "Partly cloudy",
        weatherCode: 2,
        windSpeed: 12,
        hourly: [
            HourlyWeather(time: "08:00", temperature: 9, weatherCode: 2),
            HourlyWeather(time: "14:00", temperature: 17, weatherCode: 1)
        ]
    )

    NewsHeroBanner(weather: weather, onWeatherTap: {}, onHolidayTap: {})
        .environment(AppState())
}
