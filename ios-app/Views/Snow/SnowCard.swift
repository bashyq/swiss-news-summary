import SwiftUI
import MapKit
import CoreLocation

/// Expandable card for a ski resort with snowfall forecast.
///
/// Collapsed state shows name, region, weekly snowfall total, and badges for drive time,
/// altitude, snow depth, and optional distance from user.
/// Expanded state shows a 7-day forecast with daily snowfall bars, weather icons,
/// temperature ranges, and a "Get directions" button.
struct SnowCard: View {
    let resort: SnowDestination
    let language: AppLanguage
    let isExpanded: Bool
    let userLocation: CLLocation?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsedContent
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)
                expandedContent
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    // MARK: - Collapsed Content

    private var collapsedContent: some View {
        HStack(spacing: 12) {
            // Snowflake icon with color
            snowfallIcon
                .frame(width: 36, height: 36)

            // Name and region
            VStack(alignment: .leading, spacing: 2) {
                Text(resort.localizedName(language: language))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(resort.localizedRegion(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Snowfall total
            snowfallLabel

            // Badges column
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    DriveTimeBadge(minutes: resort.driveMinutes)
                    AltitudeBadge(meters: resort.altitude)
                }
                HStack(spacing: 4) {
                    if let depth = resort.snowDepthCm {
                        snowDepthBadge(depth)
                    }
                    if let distance = distanceMeters {
                        DistanceBadge(meters: distance)
                    }
                }
            }

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
    }

    // MARK: - Snowfall Icon

    private var snowfallIcon: some View {
        Image(systemName: snowfallIconName)
            .font(.title2)
            .foregroundStyle(Color.snowColor(cm: resort.snowfallWeekTotal))
            .symbolRenderingMode(.hierarchical)
    }

    private var snowfallIconName: String {
        switch resort.snowfallLevel {
        case .heavy: return "cloud.snow.fill"
        case .moderate: return "snowflake"
        case .light: return "snowflake.circle"
        }
    }

    // MARK: - Snowfall Label

    private var snowfallLabel: some View {
        VStack(spacing: 1) {
            Text(String(format: "%.0f", resort.snowfallWeekTotal))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.snowColor(cm: resort.snowfallWeekTotal))
            Text("cm")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Snow Depth Badge

    private func snowDepthBadge(_ depth: Double) -> some View {
        BadgeView(
            text: String(format: "%.0f cm", depth),
            icon: "ruler",
            color: .cyan
        )
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 7-day forecast section
            dailyForecastSection

            // Get directions button
            directionsButton
        }
        .padding(14)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Daily Forecast

    private var dailyForecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .de ? "7-Tage-Prognose" : "7-Day Forecast")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Find max snowfall for relative bar sizing
            let maxSnowfall = resort.forecast.map(\.snowfallCm).max() ?? 1

            ForEach(resort.forecast) { day in
                dailyForecastRow(day, maxSnowfall: maxSnowfall)
            }
        }
    }

    private func dailyForecastRow(_ day: SnowDayForecast, maxSnowfall: Double) -> some View {
        HStack(spacing: 8) {
            // Day name
            Text(dayName(for: day.date))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 36, alignment: .leading)

            // Weather icon
            Image(systemName: day.sfSymbol)
                .font(.caption)
                .symbolRenderingMode(.multicolor)
                .frame(width: 20)

            // Temperature range
            Text("\(Int(day.tempMin))° / \(Int(day.tempMax))°")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            // Snowfall bar
            GeometryReader { geo in
                let maxWidth = geo.size.width
                let safeMax = max(maxSnowfall, 1)
                let barWidth = maxWidth * CGFloat(day.snowfallCm / safeMax)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.snowColor(cm: day.snowfallCm))
                        .frame(width: max(barWidth, 0), height: 6)
                }
            }
            .frame(height: 6)

            // Snowfall label
            Text(day.snowfallCm > 0 ? String(format: "%.1fcm", day.snowfallCm) : "-")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(day.snowfallCm > 0 ? Color.snowColor(cm: day.snowfallCm) : .tertiary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Directions Button

    private var directionsButton: some View {
        Button {
            openDirections()
        } label: {
            Label(
                language == .de ? "Route anzeigen" : "Get directions",
                systemImage: "car.fill"
            )
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.snowColor(cm: resort.snowfallWeekTotal).opacity(0.12))
            .foregroundStyle(Color.snowColor(cm: resort.snowfallWeekTotal))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var distanceMeters: Double? {
        guard let location = userLocation else { return nil }
        return resort.distance(from: location)
    }

    private func dayName(for dateString: String) -> String {
        guard let date = DateHelpers.parseISO(dateString) else { return dateString }
        return DateHelpers.shortDayName(date)
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: resort.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = resort.localizedName(language: language)
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

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
        forecast: [
            SnowDayForecast(date: "2026-02-16", snowfallCm: 5.2, weatherCode: 73, tempMax: -2, tempMin: -8),
            SnowDayForecast(date: "2026-02-17", snowfallCm: 12.0, weatherCode: 71, tempMax: -1, tempMin: -6),
            SnowDayForecast(date: "2026-02-18", snowfallCm: 0.0, weatherCode: 1, tempMax: 2, tempMin: -4),
            SnowDayForecast(date: "2026-02-19", snowfallCm: 3.5, weatherCode: 73, tempMax: 0, tempMin: -5),
            SnowDayForecast(date: "2026-02-20", snowfallCm: 8.0, weatherCode: 75, tempMax: -3, tempMin: -9),
            SnowDayForecast(date: "2026-02-21", snowfallCm: 0.0, weatherCode: 2, tempMax: 1, tempMin: -3),
            SnowDayForecast(date: "2026-02-22", snowfallCm: 0.0, weatherCode: 0, tempMax: 3, tempMin: -2)
        ],
        snowfallWeekTotal: 28.7,
        snowDepthCm: 145
    )

    VStack {
        SnowCard(
            resort: sampleResort,
            language: .en,
            isExpanded: true,
            userLocation: nil,
            onTap: {}
        )
    }
    .padding()
}
