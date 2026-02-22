import SwiftUI
import MapKit
import CoreLocation

/// Expandable card for a sunshine destination.
///
/// Collapsed state shows name, region, total sunshine hours, drive time badge, optional distance badge,
/// and a weather icon for the best day. Baseline destinations (Zurich) get a purple accent border.
/// Tapping expands an accordion with daily forecasts, hourly timeline, destination highlights,
/// and action buttons for directions and nearby places.
struct SunshineCard: View {
    let destination: SunshineDestination
    let language: AppLanguage
    let isExpanded: Bool
    let userLocation: CLLocation?
    var highlightID: String?
    let onTap: () -> Void

    private var isBaseline: Bool {
        destination.isBaseline == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsedContent
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)
                expandedContent
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isBaseline ? Color.purple.opacity(0.5) : .clear, lineWidth: isBaseline ? 2 : 0)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        Group {
            if isBaseline {
                Color.purple.opacity(0.06)
            } else {
                Color(.secondarySystemGroupedBackground)
            }
        }
    }

    // MARK: - Collapsed Content

    private var collapsedContent: some View {
        HStack(spacing: 12) {
            // Weather icon for best day
            bestDayIcon
                .frame(width: 36, height: 36)

            // Name and region
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isBaseline {
                        Image(systemName: "house.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    Text(destination.localizedName(language: language))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Text(destination.localizedRegion(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Sunshine hours total
            sunshineHoursLabel

            // Badges
            VStack(alignment: .trailing, spacing: 4) {
                DriveTimeBadge(minutes: destination.driveMinutes)
                if let distance = distanceMeters {
                    DistanceBadge(meters: distance)
                }
            }

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
    }

    // MARK: - Sunshine Hours Label

    private var sunshineHoursLabel: some View {
        VStack(spacing: 1) {
            Text(String(format: "%.1f", destination.sunshineHoursTotal))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.sunshineColor(hours: destination.sunshineHoursTotal))
            Text(language == .de ? "Std" : "hrs")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Best Day Icon

    private var bestDayIcon: some View {
        Group {
            if let bestDay = destination.forecast.max(by: { $0.sunshineHours < $1.sunshineHours }) {
                Image(systemName: bestDay.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(Color.sunshineColor(hours: destination.sunshineHoursTotal))
                    .symbolRenderingMode(.multicolor)
            } else {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Daily forecast rows
            dailyForecastSection

            // Hourly timeline for the best day
            hourlyTimelineSection

            // Destination highlights
            highlightsSection

            // Action buttons
            actionButtons
        }
        .padding(14)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Daily Forecast

    private var dailyForecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .de ? "Wochenendprognose" : "Weekend Forecast")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(destination.forecast) { day in
                dailyForecastRow(day)
            }
        }
    }

    private func dailyForecastRow(_ day: SunshineDayForecast) -> some View {
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

            // Sunshine hours bar
            GeometryReader { geo in
                let maxWidth = geo.size.width
                let barWidth = maxWidth * CGFloat(min(day.sunshineHours, 14)) / 14.0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.sunshineColor(hours: day.sunshineHours))
                        .frame(width: max(barWidth, 0), height: 6)
                }
            }
            .frame(height: 6)

            // Hours label
            Text(String(format: "%.1fh", day.sunshineHours))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color.sunshineColor(hours: day.sunshineHours))
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Hourly Timeline

    @ViewBuilder
    private var hourlyTimelineSection: some View {
        // Show timeline for the day with the most sunshine data
        if let bestDay = destination.forecast.max(by: { $0.sunshineHours < $1.sunshineHours }),
           let sunnyHours = bestDay.sunnyHours, !sunnyHours.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(language == .de ? "Sonnenstunden" : "Sunny Hours")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("(\(dayName(for: bestDay.date)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HourlyTimelineView(sunnyHours: sunnyHours)
            }
        }
    }

    // MARK: - Highlights

    @ViewBuilder
    private var highlightsSection: some View {
        let highlights = DestinationHighlights.forDestination(destination.id)
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(language == .de ? "Highlights" : "Things to do")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(highlights) { highlight in
                    highlightRow(highlight)
                }
            }
        }
    }

    private func highlightRow(_ highlight: DestinationHighlight) -> some View {
        HStack(spacing: 10) {
            Image(systemName: highlight.sfSymbol)
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(highlight.localizedName(language: language))
                    .font(.caption)
                    .fontWeight(.medium)
                Text(highlight.localizedDescription(language: language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Directions button
            Button {
                openDirections(to: highlight.coordinate, name: highlight.localizedName(language: language))
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            // Get directions button
            Button {
                openDirections(to: destination.coordinate, name: destination.localizedName(language: language))
            } label: {
                Label(
                    language == .de ? "Route anzeigen" : "Get directions",
                    systemImage: "car.fill"
                )
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.purple.opacity(0.12))
                .foregroundStyle(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Find playgrounds / restaurants
            HStack(spacing: 8) {
                Button {
                    searchNearby(query: "playground", coordinate: destination.coordinate)
                } label: {
                    Label(
                        language == .de ? "Spielplätze" : "Find playgrounds",
                        systemImage: "figure.play"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    searchNearby(query: "restaurant", coordinate: destination.coordinate)
                } label: {
                    Label(
                        language == .de ? "Restaurants" : "Find restaurants",
                        systemImage: "fork.knife"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var distanceMeters: Double? {
        guard let location = userLocation else { return nil }
        return destination.distance(from: location)
    }

    private func dayName(for dateString: String) -> String {
        guard let date = DateHelpers.parseISO(dateString) else { return dateString }
        return DateHelpers.shortDayName(date)
    }

    private func openDirections(to coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func searchNearby(query: String, coordinate: CLLocationCoordinate2D) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "maps://?q=\(encodedQuery)&sll=\(coordinate.latitude),\(coordinate.longitude)&z=14"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
