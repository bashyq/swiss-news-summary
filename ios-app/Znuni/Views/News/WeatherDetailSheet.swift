import SwiftUI

/// Sheet that shows expanded weather information.
///
/// Displays the current conditions (temperature, description, wind speed)
/// and an hourly forecast chart as a horizontally scrollable row of columns
/// showing hour, weather icon, and temperature. Continues into tomorrow
/// to fill the available forecast data.
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

            if let hourly = weather.hourly, !hourly.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(hourly.enumerated()), id: \.element.id) { index, entry in
                            // "Tomorrow" separator when date changes
                            if index > 0, isTomorrowBoundary(prev: hourly[index - 1], current: entry) {
                                tomorrowSeparator
                            }

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

    /// Detects when two adjacent entries cross a midnight boundary
    private func isTomorrowBoundary(prev: HourlyWeather, current: HourlyWeather) -> Bool {
        guard let prevDate = prev.parsedDate, let currDate = current.parsedDate else {
            // Fallback: check if hour wraps around (e.g., 23 → 0)
            guard let prevHour = prev.hour, let currHour = current.hour else { return false }
            return currHour < prevHour
        }
        return !Calendar.current.isDate(prevDate, inSameDayAs: currDate)
    }

    private var tomorrowSeparator: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color.znBorder)
                .frame(width: 1, height: 20)

            Text(appState.localized(en: "Tomorrow", de: "Morgen"))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.znMuted)
                .textCase(.uppercase)

            Rectangle()
                .fill(Color.znBorder)
                .frame(width: 1, height: 20)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Hour Column

    private func hourColumn(_ entry: HourlyWeather) -> some View {
        let current = isCurrentHour(entry)
        return hourColumnContent(entry: entry, isCurrent: current)
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
        let now = Date()
        let currentHour = Calendar.current.component(.hour, from: now)
        // Only highlight if entry is today
        if let entryDate = entry.parsedDate {
            guard Calendar.current.isDateInToday(entryDate) else { return false }
        }
        return hour == currentHour
    }
}

// MARK: - HourlyWeather Date Parsing

private extension HourlyWeather {
    /// Parses the ISO timestamp to a Date (handles "2026-03-14T14:00" format)
    var parsedDate: Date? {
        guard time.contains("T") else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        // Open-Meteo returns local time without timezone suffix, so parse manually
        let components = time.split(separator: "T")
        guard components.count == 2 else { return nil }
        let dateParts = components[0].split(separator: "-")
        let timeParts = components[1].split(separator: ":")
        guard dateParts.count == 3, timeParts.count >= 2,
              let year = Int(dateParts[0]), let month = Int(dateParts[1]), let day = Int(dateParts[2]),
              let hour = Int(timeParts[0]), let minute = Int(timeParts[1]) else { return nil }
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }
}

#Preview {
    let sampleHourly = (14...23).map { hour in
        HourlyWeather(
            time: "2026-02-21T\(String(format: "%02d", hour)):00",
            temperature: Double.random(in: 2...12),
            weatherCode: [0, 1, 2, 3, 45, 61].randomElement()!
        )
    } + (0...10).map { hour in
        HourlyWeather(
            time: "2026-02-22T\(String(format: "%02d", hour)):00",
            temperature: Double.random(in: 0...8),
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
