import SwiftUI

/// Compact weather display shown in the News view header.
///
/// Displays an SF Symbol for the current weather code, temperature, and description.
/// Tapping the view triggers the `onTap` closure to present the detail sheet.
struct WeatherCompactView: View {
    let weather: Weather
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Weather icon
                Image(systemName: weather.sfSymbol)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)

                // Temperature (large)
                Text(temperatureText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()

                // Description
                Text(weather.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                // Expand hint
                Image(systemName: "chevron.down.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.weatherCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tap to see hourly forecast")
    }

    // MARK: - Helpers

    private var temperatureText: String {
        "\(Int(weather.temperature.rounded()))\u{00B0}"
    }

    private var accessibilityDescription: String {
        "\(Int(weather.temperature.rounded())) degrees, \(weather.description)"
    }
}

#Preview {
    let sampleWeather = Weather(
        temperature: 8.5,
        description: "Partly cloudy",
        weatherCode: 2,
        windSpeed: 12.0,
        hourly: nil
    )

    WeatherCompactView(weather: sampleWeather) {
        // tap action
    }
    .padding()
}
