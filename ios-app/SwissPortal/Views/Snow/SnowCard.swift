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
                    .padding(.horizontal, AppSpacing.cardPadding)
                expandedContent
            }
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.snowColor(cm: resort.snowfallWeekTotal))
                .frame(width: AppSpacing.borderStripWidth)
                .padding(.vertical, 6)
        }
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
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
                    .font(.cardTitle)
                    .lineLimit(1)
                Text(resort.localizedRegion(language: language))
                    .font(.caption)
                    .foregroundStyle(.znMuted)
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
                    snowDepthBadge(resort.snowDepthCm)
                    if let distance = distanceMeters {
                        DistanceBadge(meters: distance)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.znChevron)
        }
        .padding(AppSpacing.cardPadding)
    }

    // MARK: - Snowfall Icon

    private var snowfallIcon: some View {
        Image(systemName: snowfallIconName)
            .font(.system(size: 24))
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
                .font(.cardHeadline)
                .foregroundStyle(Color.snowColor(cm: resort.snowfallWeekTotal))
                .contentTransition(.numericText())
            Text("cm")
                .font(.caption2)
                .foregroundStyle(.znMuted)
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
            // Resort photo banner
            resortPhoto

            // 7-day forecast section
            dailyForecastSection

            // Get directions button
            directionsButton
        }
        .padding(AppSpacing.cardPadding)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Resort Photo

    @ViewBuilder
    private var resortPhoto: some View {
        if let photoURL = APIClient.shared.photoURL(for: resort.id) {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    EmptyView()
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.znBorder)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .overlay { ProgressView() }
                }
            }
        }
    }

    // MARK: - Daily Forecast

    private var dailyForecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .de ? "Prognose" : "Forecast")
                .font(.znEyebrow)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.znMuted)

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
                        .fill(Color.znBorder)
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
                .foregroundStyle(day.snowfallCm > 0 ? Color.snowColor(cm: day.snowfallCm) : Color.znMuted)
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
            .background(Color.brand.opacity(0.12))
            .foregroundStyle(.brand)
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
    VStack {
        SnowCard(
            resort: PreviewData.snowDestination,
            language: .en,
            isExpanded: true,
            userLocation: nil,
            onTap: {}
        )
    }
    .padding()
}
