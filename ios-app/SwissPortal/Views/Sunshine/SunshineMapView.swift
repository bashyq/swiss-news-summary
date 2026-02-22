import SwiftUI
import MapKit

/// MapKit map displaying sunshine destinations as color-coded circles.
///
/// - Circle radius is proportional to total sunshine hours
/// - Circle color uses Color.sunshineColor(hours:) — gold for sunny, blue for partly, gray for cloudy
/// - Zurich baseline destination is shown with a purple circle
/// - Centered on Switzerland with zoom to fit all destinations
/// - Tapping a circle triggers the onDestinationTapped callback
struct SunshineMapView: View {
    let destinations: [SunshineDestination]
    let language: AppLanguage
    var onDestinationTapped: ((SunshineDestination) -> Void)?

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.8, longitude: 8.2),
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 3.0)
        )
    )

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(destinations) { destination in
                MapCircle(
                    center: destination.coordinate,
                    radius: circleRadius(for: destination)
                )
                .foregroundStyle(circleColor(for: destination).opacity(0.4))
                .stroke(circleColor(for: destination), lineWidth: 2)
                .mapOverlayLevel(level: .aboveRoads)

                Annotation(
                    destination.localizedName(language: language),
                    coordinate: destination.coordinate,
                    anchor: .center
                ) {
                    Button {
                        onDestinationTapped?(destination)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: destination.isBaseline == true ? "house.fill" : "sun.max.fill")
                                .font(.caption2)
                                .foregroundStyle(circleColor(for: destination))
                            Text(String(format: "%.0fh", destination.sunshineHoursTotal))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(circleColor(for: destination))
                        }
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    // MARK: - Circle Styling

    /// Radius proportional to total sunshine hours, clamped to a reasonable range.
    /// Baseline gets a fixed smaller radius.
    private func circleRadius(for destination: SunshineDestination) -> CLLocationDistance {
        if destination.isBaseline == true {
            return 3000
        }
        // Scale: 0 hours -> 2km radius, 20+ hours -> 8km radius
        let normalized = min(destination.sunshineHoursTotal, 20)
        return 2000 + (normalized / 20) * 6000
    }

    /// Color based on sunshine level. Purple for baseline (Zurich).
    private func circleColor(for destination: SunshineDestination) -> Color {
        if destination.isBaseline == true {
            return .purple
        }
        return .sunshineColor(hours: destination.sunshineHoursTotal)
    }
}

#Preview {
    SunshineMapView(
        destinations: [],
        language: .en
    )
    .frame(height: 300)
}
