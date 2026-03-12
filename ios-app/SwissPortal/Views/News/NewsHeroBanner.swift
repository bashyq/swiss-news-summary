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
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))

                    // Title: "Today in" / "Zürich" (italic)
                    titleText
                }

                Spacer()

                cityMenuButton
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
                skylineIllustration
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

        return VStack(alignment: .leading, spacing: 0) {
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

    /// City skyline silhouette — buildings, church spires, rooftops (matches mockup SVG)
    private var skylineIllustration: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let white = Color.white
            // Building 1: tower with spire
            ctx.fill(Path(CGRect(x: w * 0.05, y: h * 0.36, width: w * 0.09, height: h * 0.64)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.05, y: h * 0.36))
                p.addLine(to: CGPoint(x: w * 0.095, y: h * 0.11))
                p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.36))
                p.closeSubpath()
            }, with: .color(white))
            // Building 2: wider with triangular roof
            ctx.fill(Path(CGRect(x: w * 0.19, y: h * 0.45, width: w * 0.11, height: h * 0.55)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.19, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.245, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.45))
                p.closeSubpath()
            }, with: .color(white))
            // Building 3: dome building
            ctx.fill(Path(CGRect(x: w * 0.36, y: h * 0.41, width: w * 0.08, height: h * 0.59)), with: .color(white))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.32, y: h * 0.29, width: w * 0.16, height: h * 0.18)), with: .color(white))
            // Building 4: tall rectangular with cap
            ctx.fill(Path(CGRect(x: w * 0.50, y: h * 0.32, width: w * 0.14, height: h * 0.68)), with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.525, y: h * 0.20, width: w * 0.09, height: h * 0.15)), with: .color(white))
            // Building 5: church spire
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.69, y: h))
                p.addLine(to: CGPoint(x: w * 0.79, y: h * 0.25))
                p.addLine(to: CGPoint(x: w * 0.89, y: h))
                p.closeSubpath()
            }, with: .color(white))
            // Horizon bar
            ctx.fill(Path(CGRect(x: 0, y: h * 0.76, width: w, height: h * 0.13)), with: .color(white.opacity(0.25)))
        }
    }

    // MARK: - City Menu Button

    private var cityMenuButton: some View {
        Menu {
            ForEach(City.allCases) { city in
                Button {
                    appState.city = city
                } label: {
                    HStack {
                        Text(city.localizedName(language: appState.language))
                        if city == appState.city {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "building.2")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
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
