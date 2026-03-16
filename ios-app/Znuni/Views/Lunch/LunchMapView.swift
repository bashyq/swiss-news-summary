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
    var userFocusLocation: CLLocation?
    @Binding var focusedSpot: LunchSpot?

    @State private var selectedSpot: LunchSpot?
    @State private var cameraPosition: MapCameraPosition

    init(spots: [LunchSpot], city: City, language: AppLanguage, userFocusLocation: CLLocation? = nil, focusedSpot: Binding<LunchSpot?> = .constant(nil)) {
        self.spots = spots
        self.city = city
        self.language = language
        self.userFocusLocation = userFocusLocation
        self._focusedSpot = focusedSpot
        // Center on user location if available, otherwise city
        let center = userFocusLocation?.coordinate ?? city.coordinate
        let region = MKCoordinateRegion(
            center: center,
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
        .onChange(of: userFocusLocation?.coordinate.latitude) { _, _ in
            if let loc = userFocusLocation {
                withAnimation {
                    let region = MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                    )
                    cameraPosition = .region(region)
                }
            }
        }
        .onChange(of: focusedSpot?.id) { _, _ in
            if let spot = focusedSpot {
                withAnimation {
                    let region = MKCoordinateRegion(
                        center: spot.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    cameraPosition = .region(region)
                    selectedSpot = spot
                }
                focusedSpot = nil
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.znCream.opacity(0.8)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 20)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if let selected = selectedSpot {
                selectedSpotCard(selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if spots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(language == .en ? "No restaurants on map" : "Keine Restaurants auf der Karte")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.znCream.opacity(0.6))
            }
        }
    }

    // MARK: - Marker Color

    private func markerColor(for spot: LunchSpot) -> Color {
        switch spot.cuisineCategory?.lowercased() {
        case "swiss": return .znNegative
        case "italian": return .znPositive
        case "asian": return .znTerracotta
        case "kebab": return .znTerracotta.opacity(0.7)
        case "cafe": return .znNavy.opacity(0.65)
        case "vegetarian": return .znPositive.opacity(0.8)
        case "fastfood": return .znTerracotta.opacity(0.85)
        default: return .znNavy
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
                .accessibilityLabel(language == .en ? "Dismiss" : "Schließen")
            }

            Text(spot.cuisineDisplay)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if spot.openForLunch == true {
                    BadgeView(
                        text: language == .en ? "Open for lunch" : "Mittagstisch",
                        icon: "clock",
                        color: .znPositive
                    )
                }

                if spot.outdoorSeating == true {
                    BadgeView(
                        text: language == .en ? "Outdoor" : "Terrasse",
                        icon: "sun.max.fill",
                        color: .znTerracotta
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
                    .foregroundStyle(.brand)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: -AppShadow.card.y)
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

extension LunchSpot: Hashable {
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
    .frame(height: AppSpacing.mapHeight)
}
