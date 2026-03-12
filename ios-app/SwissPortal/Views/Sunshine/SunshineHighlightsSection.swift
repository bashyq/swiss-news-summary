import SwiftUI
import MapKit
import CoreLocation

/// Extracted from SunshineCard — displays destination highlights and action buttons.
///
/// Shows curated toddler-friendly attractions for a sunshine destination,
/// plus buttons for getting directions and finding nearby playgrounds/restaurants.
struct SunshineHighlightsSection: View {
    @Environment(AppState.self) private var appState

    let destination: SunshineDestination
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Destination highlights
            highlightsContent

            // Action buttons
            actionButtons

            // Cross-navigation for overlap cities
            if DestinationHighlights.activityCities.contains(destination.id) {
                Button {
                    if let city = City(rawValue: destination.id) {
                        appState.city = city
                    }
                    appState.selectedTab = .activities
                } label: {
                    Label(
                        language == .de ? "Alle Aktivitäten \u{2192}" : "See all activities \u{2192}",
                        systemImage: "figure.play"
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.brand.opacity(0.12))
                    .foregroundStyle(.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Highlights

    @ViewBuilder
    private var highlightsContent: some View {
        let highlights = destination.highlights ?? DestinationHighlights.forDestination(destination.id)
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
                .foregroundStyle(.brand)
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
                    .foregroundStyle(.znNavy)
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
                .background(Color.brand.opacity(0.12))
                .foregroundStyle(.brand)
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
                    .background(Color.znNeutralTagBg)
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
                    .background(Color.znNeutralTagBg)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

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
