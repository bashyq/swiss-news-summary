import SwiftUI

/// Sheet that shows expanded weather information.
///
/// Displays the current conditions (temperature, description, wind speed)
/// and an hourly forecast chart as a horizontally scrollable row of columns
/// showing hour, weather icon, and temperature for hours 6 through 22.
struct WeatherDetailSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let weather: Weather

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    currentConditions
                    Divider()
                        .padding(.horizontal, 32)
                    hourlyForecast
                }
                .padding()
            }
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

    // MARK: - Current Conditions

    private var currentConditions: some View {
        VStack(spacing: 8) {
            // Weather icon
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: weather.sfSymbol)
                    .font(.system(size: 30))
                    .symbolRenderingMode(.multicolor)
            }

            // Temperature
            Text("\(Int(weather.temperature.rounded()))\u{00B0}")
                .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                .monospacedDigit()

            // Description
            Text(weather.description)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Wind speed pill
            HStack(spacing: 6) {
                Image(systemName: "wind")
                    .font(.caption)
                Text("\(Int(weather.windSpeed.rounded())) km/h")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.znBorder.opacity(0.5))
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Hourly Forecast

    private var hourlyForecast: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.localized(en: "Hourly Forecast", de: "Stundenprognose"))
                .font(.headline)

            if let hourly = filteredHourly, !hourly.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(hourly) { entry in
                            hourColumn(entry)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text(appState.localized(
                    en: "No hourly data available",
                    de: "Keine Stundendaten verfuegbar"
                ))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            }
        }
    }

    /// Hourly entries filtered to hours 6 through 22
    private var filteredHourly: [HourlyWeather]? {
        weather.hourly?.filter { entry in
            guard let hour = entry.hour else { return false }
            return hour >= 6 && hour <= 22
        }
    }

    // MARK: - Hour Column

    private func hourColumn(_ entry: HourlyWeather) -> some View {
        hourColumnContent(entry: entry, isCurrent: isCurrentHour(entry))
    }

    private func hourColumnContent(entry: HourlyWeather, isCurrent: Bool) -> some View {
        VStack(spacing: 6) {
            // Hour label
            Text(hourLabel(entry))
                .font(.caption2)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundStyle(isCurrent ? .primary : .secondary)

            // Weather icon
            Image(systemName: entry.sfSymbol)
                .font(.title3)
                .symbolRenderingMode(.multicolor)
                .frame(height: 28)

            // Temperature
            Text("\(Int(entry.temperature.rounded()))\u{00B0}")
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .frame(width: 50)
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .fill(isCurrent ? Color.brand.opacity(0.12) : Color.znBorder.opacity(0.5).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .strokeBorder(isCurrent ? Color.brand.opacity(0.3) : .clear, lineWidth: 1)
        )
    }

    private func hourLabel(_ entry: HourlyWeather) -> String {
        guard let hour = entry.hour else { return "--" }
        return String(format: "%02d:00", hour)
    }

    private func isCurrentHour(_ entry: HourlyWeather) -> Bool {
        guard let hour = entry.hour else { return false }
        let currentHour = Calendar.current.component(.hour, from: Date())
        return hour == currentHour
    }
}

#Preview {
    let sampleHourly = (6...22).map { hour in
        HourlyWeather(
            time: "2026-02-21T\(String(format: "%02d", hour)):00",
            temperature: Double.random(in: 2...12),
            weatherCode: [0, 1, 2, 3, 45, 61].randomElement()!
        )
    }

    let sampleWeather = Weather(
        temperature: 8.5,
        description: "Partly cloudy",
        weatherCode: 2,
        windSpeed: 12.0,
        hourly: sampleHourly
    )

    WeatherDetailSheet(weather: sampleWeather)
        .environment(AppState())
}
