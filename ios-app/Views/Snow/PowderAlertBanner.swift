import SwiftUI

/// Alert banner displayed when the top ski resort has more than 40cm of weekly snowfall.
///
/// Shows a "Fresh powder!" message with the resort name and snowfall amount.
/// Uses a blue gradient background with a snowflake icon.
struct PowderAlertBanner: View {
    let resort: SnowDestination
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            // Snowflake icon
            Image(systemName: "snowflake")
                .font(.title2)
                .foregroundStyle(.white)
                .symbolEffect(.bounce, options: .repeating.speed(0.3))

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(language == .de ? "Frischer Pulverschnee!" : "Fresh powder!")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Text(resort.localizedName(language: language))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.95))

                    Text("·")
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                        Text(String(format: "%.0f cm", resort.snowfallWeekTotal))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white.opacity(0.95))

                    Text("·")
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 3) {
                        Image(systemName: "car.fill")
                            .font(.caption2)
                        Text(CLLocation.formattedDriveTime(resort.driveMinutes))
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.8),
                    Color(red: 0.2, green: 0.4, blue: 0.9),
                    Color(red: 0.3, green: 0.5, blue: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

import CoreLocation

#Preview {
    let sampleResort = SnowDestination(
        id: "zermatt",
        name: "Zermatt",
        nameDE: "Zermatt",
        lat: 46.0207,
        lon: 7.7491,
        region: "Valais",
        regionDE: "Wallis",
        driveMinutes: 195,
        altitude: 1620,
        forecast: [],
        snowfallWeekTotal: 48.5,
        snowDepthCm: 180
    )

    VStack {
        PowderAlertBanner(
            resort: sampleResort,
            language: .en
        )
        .padding()

        PowderAlertBanner(
            resort: sampleResort,
            language: .de
        )
        .padding()
    }
}
