import SwiftUI
import MapKit

/// MapKit map displaying activity locations as color-coded markers.
///
/// - Indoor activities are shown with blue markers
/// - Outdoor activities are shown with orange markers
/// - The map centers on the selected city with an appropriate zoom level
/// - Tapping a marker selects the activity and shows a callout
struct ActivityMapView: View {
    let activities: [Activity]
    let city: City
    let language: AppLanguage
    var userFocusLocation: CLLocation?

    @State private var selectedActivity: Activity?
    @State private var cameraPosition: MapCameraPosition

    init(activities: [Activity], city: City, language: AppLanguage, userFocusLocation: CLLocation? = nil) {
        self.activities = activities
        self.city = city
        self.language = language
        self.userFocusLocation = userFocusLocation
        let center = userFocusLocation?.coordinate ?? city.coordinate
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        _cameraPosition = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedActivity) {
            ForEach(activitiesWithCoordinates) { activity in
                Marker(
                    activity.localizedName(language: language),
                    systemImage: markerIcon(for: activity),
                    coordinate: activity.coordinate!
                )
                .tint(markerColor(for: activity))
                .tag(activity)
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
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
                cameraPosition = .region(region)
            }
        }
        .onChange(of: userFocusLocation?.coordinate.latitude) { _, _ in
            if let loc = userFocusLocation {
                withAnimation {
                    let region = MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                    )
                    cameraPosition = .region(region)
                }
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
            if let selected = selectedActivity {
                selectedActivityCard(selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if activitiesWithCoordinates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(language == .en ? "No activities on map" : "Keine Aktivitäten auf der Karte")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.znCream.opacity(0.6))
            }
        }
    }

    // MARK: - Activities with Coordinates

    private var activitiesWithCoordinates: [Activity] {
        activities.filter { $0.coordinate != nil }
    }

    // MARK: - Marker Styling

    private func markerColor(for activity: Activity) -> Color {
        if activity.isFree {
            return .znPositive
        }
        return activity.indoor ? .znNavy : .znTerracotta
    }

    private func markerIcon(for activity: Activity) -> String {
        switch activity.category.lowercased() {
        case "animals": return "pawprint.fill"
        case "playground": return "figure.play"
        case "museum": return "building.columns.fill"
        case "nature": return "leaf.fill"
        case "water": return "drop.fill"
        case "transport": return "tram.fill"
        case "creative": return "paintpalette.fill"
        case "music": return "music.note"
        case "sports": return "sportscourt.fill"
        case "food": return "fork.knife"
        default: return "star.fill"
        }
    }

    // MARK: - Selected Activity Card

    @ViewBuilder
    private func selectedActivityCard(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: markerIcon(for: activity))
                    .font(.caption)
                    .foregroundStyle(markerColor(for: activity))
                Text(activity.localizedName(language: language))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Button {
                    withAnimation {
                        selectedActivity = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language == .en ? "Dismiss" : "Schließen")
            }

            Text(activity.localizedDescription(language: language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                BadgeView(
                    text: activity.indoor
                        ? (language == .en ? "Indoor" : "Indoor")
                        : (language == .en ? "Outdoor" : "Outdoor"),
                    icon: activity.indoor ? "house.fill" : "sun.max.fill",
                    color: activity.indoor ? .znNavy : .znTerracotta
                )

                BadgeView(text: activity.duration, icon: "clock", color: .znMuted)

                if activity.isFree {
                    FreeBadge()
                }

                Spacer()

                if let urlString = activity.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text(language == .en ? "Open" : "Öffnen")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(.brand)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Activity + Hashable for Map Selection

extension Activity: Hashable {
    static func == (lhs: Activity, rhs: Activity) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    ActivityMapView(
        activities: [],
        city: .zurich,
        language: .en
    )
}
