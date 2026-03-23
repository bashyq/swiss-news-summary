import SwiftUI

/// Full-width navy gradient hero for the Plan tab.
///
/// Matches the Znuni hero pattern: VStack content with `.background {}` modifier.
/// Shows date eyebrow, "Plan your _Saturday_" title, weather row, city picker glass button.
struct PlanHeroBanner: View {
    @Environment(AppState.self) private var appState

    let selectedDate: Date
    let planState: PlanState
    let weather: Weather?
    let forecast: DailyForecast?
    let isToday: Bool
    let planningCity: PlanningCity
    var onWeatherTap: (() -> Void)?
    var onCityChange: ((PlanningCity) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: date eyebrow + city picker
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrowDate)
                        .font(.znEyebrow)
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))

                    // Title
                    titleText
                }

                Spacer()

                cityPickerButton
            }
            .padding(.bottom, 18)

            // Weather row — for today show live weather; for future dates show forecast
            if isToday, let weather {
                Button { onWeatherTap?() } label: {
                    weatherRow(weather)
                }
                .buttonStyle(.plain)
            } else if let forecast {
                forecastRow(forecast)
            } else if let weather {
                // Fallback: show today's weather even for future dates if no forecast loaded yet
                Button { onWeatherTap?() } label: {
                    weatherRow(weather)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy
                    .ignoresSafeArea(.container, edges: .top)

                RadialGradient(
                    colors: [Color.znTerracotta.opacity(0.22), .clear],
                    center: UnitPoint(x: 1.2, y: -0.3),
                    startRadius: 0,
                    endRadius: 220
                )

                SkylineIllustration()
                    .frame(width: 200, height: 110)
                    .opacity(0.09)
            }
        }
    }

    // MARK: - Eyebrow Date

    private var eyebrowDate: String {
        let f = DateFormatter()
        f.locale = appState.language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        f.dateFormat = appState.language == .de ? "EEEE · d. MMMM" : "EEEE · d MMMM"
        return f.string(from: selectedDate)
    }

    // MARK: - Title

    private var titleText: some View {
        let dayName = formattedDayName

        return HStack(spacing: 6) {
            Text(titlePrefix)
                .font(.heroTitle)
                .foregroundStyle(.white)
            Text(dayName)
                .font(.custom("Playfair", size: 30).italic())
                .foregroundStyle(.white.opacity(0.68))
        }
    }

    private var titlePrefix: String {
        switch planState {
        case .dealt, .saved:
            return appState.localized(en: "Your", de: "Dein")
        case .composing:
            return appState.localized(en: "Planning your", de: "Plane deinen")
        default:
            return appState.localized(en: "Plan your", de: "Plane deinen")
        }
    }

    private var formattedDayName: String {
        let f = DateFormatter()
        f.locale = appState.language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        f.dateFormat = "EEEE"
        var name = f.string(from: selectedDate)
        if case .composing = planState {
            name += "..."
        }
        return name
    }

    // MARK: - Weather Row

    private func weatherRow(_ weather: Weather) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(Int(weather.temperature))\u{00B0}")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))

                if let high = weather.highTemp, let low = weather.lowTemp {
                    Text("H: \(Int(high))\u{00B0}  \u{00B7}  L: \(Int(low))\u{00B0}")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            Spacer()

            Image(systemName: weather.sfSymbol)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.yellow)
                .font(.system(size: 36))
        }
    }

    // MARK: - Forecast Row (future dates)

    private func forecastRow(_ forecast: DailyForecast) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(Int(forecast.highTemp))\u{00B0}")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))

                Text("H: \(Int(forecast.highTemp))\u{00B0}  \u{00B7}  L: \(Int(forecast.lowTemp))\u{00B0}")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer()

            Image(systemName: forecast.sfSymbol)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.yellow)
                .font(.system(size: 36))
        }
    }

    // MARK: - City Picker Glass Button

    private var cityPickerButton: some View {
        Menu {
            ForEach(PlanningCity.coveredCities, id: \.id) { pc in
                Button {
                    onCityChange?(pc)
                } label: {
                    HStack {
                        Text(pc.localizedName(language: appState.language))
                        if pc == planningCity {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(planningCity.localizedName(language: appState.language))
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.12))
            )
        }
    }
}
