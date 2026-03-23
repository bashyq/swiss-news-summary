import SwiftUI
import MapKit

/// MapKit map displaying ski resorts as color-coded circles.
///
/// - Circle radius is proportional to weekly snowfall total
/// - Circle color uses Color.snowColor(cm:) — deep blue for heavy, blue for moderate, gray for light
/// - Centered on the Swiss Alps with zoom to fit all resorts
/// - Tapping a circle triggers the onResortTapped callback
struct SnowMapView: View {
    let destinations: [SnowDestination]
    let language: AppLanguage
    var userFocusLocation: CLLocation?
    var onResortTapped: ((SnowDestination) -> Void)?

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 8.2),
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.5)
        )
    )

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Map(position: $cameraPosition) {
                ForEach(destinations) { resort in
                    MapCircle(
                        center: resort.coordinate,
                        radius: circleRadius(for: resort)
                    )
                    .foregroundStyle(circleColor(for: resort).opacity(0.4))
                    .stroke(circleColor(for: resort), lineWidth: 2)
                    .mapOverlayLevel(level: .aboveRoads)

                    Annotation(
                        resort.localizedName(language: language),
                        coordinate: resort.coordinate,
                        anchor: .center
                    ) {
                        Button {
                            onResortTapped?(resort)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "snowflake")
                                    .font(.caption2)
                                    .foregroundStyle(circleColor(for: resort))
                                Text(String(format: "%.0fcm", resort.snowfallWeekTotal))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(circleColor(for: resort))
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
                MapUserLocationButton()
            }
            .mapStyle(.standard(elevation: .realistic))
            .onChange(of: userFocusLocation?.coordinate.latitude) { _, _ in
                if let loc = userFocusLocation {
                    withAnimation {
                        let region = MKCoordinateRegion(
                            center: loc.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 2.0)
                        )
                        cameraPosition = .region(region)
                    }
                }
            }

            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.znCream.opacity(0.8)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 20)
                .allowsHitTesting(false)
            }

            MapLegend(items: [
                .init(color: .znNavy, label: ">30cm"),
                .init(color: .znNavy.opacity(0.6), label: "10-30cm"),
                .init(color: .znMuted, label: "<10cm"),
            ])
            .padding(8)
        }
    }

    // MARK: - Circle Styling

    /// Radius proportional to weekly snowfall, clamped to a reasonable range.
    private func circleRadius(for resort: SnowDestination) -> CLLocationDistance {
        // Scale: 0cm -> 2km radius, 50+ cm -> 8km radius
        let normalized = min(resort.snowfallWeekTotal, 50)
        return 2000 + (normalized / 50) * 6000
    }

    /// Color based on snowfall level.
    private func circleColor(for resort: SnowDestination) -> Color {
        .snowColor(cm: resort.snowfallWeekTotal)
    }
}

#Preview {
    SnowMapView(
        destinations: [],
        language: .en
    )
    .frame(height: AppSpacing.mapHeight)
}
