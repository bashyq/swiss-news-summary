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
                // Weather icon with subtle background circle
                Image(systemName: weather.sfSymbol)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.znBorder.opacity(0.5))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // Temperature (large)
                    Text(temperatureText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()

                    // Description
                    Text(weather.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Hourly hint
                if weather.hourly != nil {
                    HStack(spacing: 4) {
                        Text("Hourly")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.weatherCard)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
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
