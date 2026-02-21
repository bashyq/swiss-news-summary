import SwiftUI

/// Banner shown when the Zurich baseline has less than 6 hours of sunshine.
///
/// Displays the nearest destination with more sunshine and its drive time.
/// Tapping the banner triggers scrolling to the corresponding card.
/// Uses a warm gradient background to draw attention.
struct SunnyEscapeBanner: View {
    let destination: SunshineDestination
    let language: AppLanguage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Sun icon
                Image(systemName: "sun.max.trianglebadge.exclamationmark.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(language == .de ? "Nächste Sonnenflucht" : "Nearest sunny escape")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 6) {
                        Text(destination.localizedName(language: language))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("·")
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 3) {
                            Image(systemName: "car.fill")
                                .font(.caption2)
                            Text(CLLocation.formattedDriveTime(destination.driveMinutes))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f", destination.sunshineHoursTotal))
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(language == .de ? "Std Sonne" : "hrs sunshine")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.orange,
                        Color.orange.opacity(0.85),
                        Color.yellow.opacity(0.7)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

import CoreLocation

#Preview {
    let sampleDest = SunshineDestination(
        id: "lugano",
        name: "Lugano",
        nameDE: "Lugano",
        lat: 46.0037,
        lon: 8.9511,
        region: "Ticino",
        regionDE: "Tessin",
        driveMinutes: 150,
        forecast: [],
        sunshineHoursTotal: 15.7,
        isBaseline: false
    )

    VStack {
        SunnyEscapeBanner(
            destination: sampleDest,
            language: .en,
            onTap: {}
        )
        .padding()

        SunnyEscapeBanner(
            destination: sampleDest,
            language: .de,
            onTap: {}
        )
        .padding()
    }
}
