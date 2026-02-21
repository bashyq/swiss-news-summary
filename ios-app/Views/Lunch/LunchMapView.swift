import SwiftUI
import MapKit

/// MapKit map displaying lunch spot locations as color-coded markers.
///
/// - Markers are color-coded by cuisine category
/// - The map centers on the selected city with an appropriate zoom level
/// - Tapping a marker selects the spot and shows an overlay card
struct LunchMapView: View {
    let spots: [LunchSpot]
    let city: City
    let language: AppLanguage

    @State private var selectedSpot: LunchSpot?
    @State private var cameraPosition: MapCameraPosition

    init(spots: [LunchSpot], city: City, language: AppLanguage) {
        self.spots = spots
        self.city = city
        self.language = language
        // Center on the city coordinate with a ~5 km span (tighter for restaurant density)
        let region = MKCoordinateRegion(
            center: city.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
        _cameraPosition = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedSpot) {
            ForEach(spots) { spot in
                Marker(
                    spot.name,
                    systemImage: spot.cuisineSFSymbol,
                    coordinate: spot.coordinate
                )
                .tint(markerColor(for: spot))
                .tag(spot)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .onChange(of: city) { _, newCity in
            withAnimation {
                let region = MKCoordinateRegion(
                    center: newCity.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                )
                cameraPosition = .region(region)
            }
        }
        .overlay(alignment: .bottom) {
            if let selected = selectedSpot {
                selectedSpotCard(selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Marker Color

    private func markerColor(for spot: LunchSpot) -> Color {
        switch spot.cuisineCategory?.lowercased() {
        case "swiss": return .red
        case "italian": return .green
        case "asian": return .orange
        case "kebab": return .brown
        case "cafe": return .purple
        case "vegetarian": return .mint
        case "fastfood": return .yellow
        default: return .blue
        }
    }

    // MARK: - Selected Spot Card

    @ViewBuilder
    private func selectedSpotCard(_ spot: LunchSpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: spot.cuisineSFSymbol)
                    .font(.caption)
                    .foregroundStyle(markerColor(for: spot))
                Text(spot.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Button {
                    withAnimation {
                        selectedSpot = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(spot.cuisineDisplay)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if spot.openForLunch == true {
                    BadgeView(
                        text: language == .en ? "Open for lunch" : "Mittagstisch",
                        icon: "clock",
                        color: .green
                    )
                }

                if spot.outdoorSeating == true {
                    BadgeView(
                        text: language == .en ? "Outdoor" : "Terrasse",
                        icon: "sun.max.fill",
                        color: .orange
                    )
                }

                if spot.vegetarian == true {
                    BadgeView(
                        text: language == .en ? "Vegetarian" : "Vegetarisch",
                        icon: "leaf",
                        color: .green
                    )
                }

                Spacer()

                // Directions button
                Button {
                    openInMaps(spot)
                } label: {
                    HStack(spacing: 4) {
                        Text(language == .en ? "Directions" : "Route")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func openInMaps(_ spot: LunchSpot) {
        let urlString = "http://maps.apple.com/?daddr=\(spot.lat),\(spot.lon)&dirflg=w"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - LunchSpot + Hashable for Map Selection

extension LunchSpot: @retroactive Hashable {
    static func == (lhs: LunchSpot, rhs: LunchSpot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    LunchMapView(
        spots: [],
        city: .zurich,
        language: .en
    )
    .frame(height: 240)
}
