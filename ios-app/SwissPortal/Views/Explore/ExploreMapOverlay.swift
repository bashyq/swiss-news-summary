import SwiftUI
import MapKit

/// Inline map view with colored pins and bottom-sheet pin detail card.
/// Embeddable within ExploreView (not a fullScreenCover).
struct ExploreMapOverlay: View {
    @Environment(AppState.self) private var appState

    let items: [ExploreItem]
    let onCollapse: () -> Void
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedItem: ExploreItem?

    init(items: [ExploreItem], city: City, onCollapse: @escaping () -> Void, initialSelection: ExploreItem? = nil) {
        self.items = items
        self.onCollapse = onCollapse
        if let item = initialSelection {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: item.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )))
            _selectedItem = State(initialValue: item)
        } else {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: city.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )))
        }
    }

    var body: some View {
        ZStack {
            mapView

            // Collapse button — floating on the map
            VStack {
                HStack {
                    Spacer()
                    Button(action: onCollapse) {
                        Label(appState.localized(en: "Collapse", de: "Verkleinern"), systemImage: "arrow.down.right.and.arrow.up.left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.znNavy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Spacer()
            }

            // Legend
            VStack {
                Spacer()
                HStack {
                    legendBar
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, selectedItem != nil ? 180 : 12)
            }

            // Pin detail card
            if let selected = selectedItem {
                VStack {
                    Spacer()
                    pinDetailCard(selected)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $cameraPosition) {
            ForEach(items) { item in
                Annotation(item.localizedName(language: appState.language), coordinate: item.coordinate) {
                    annotationView(for: item)
                        .onTapGesture {
                            withAnimation(AppAnimation.spring) {
                                selectedItem = item
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: item.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                ))
                            }
                        }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    private func annotationView(for item: ExploreItem) -> some View {
        let isSelected = selectedItem?.id == item.id
        let color: Color = switch item {
        case .activity: .znTerracotta
        case .event: .znNavy
        case .deal: .znPositive
        }
        let symbol: String = switch item {
        case .activity: "mappin.circle.fill"
        case .event: "star.circle.fill"
        case .deal: "tag.circle.fill"
        }

        return Image(systemName: symbol)
            .font(isSelected ? .title : .title2)
            .foregroundStyle(color)
            .background(
                Circle()
                    .fill(.white)
                    .frame(width: isSelected ? 24 : 20, height: isSelected ? 24 : 20)
            )
            .shadow(color: isSelected ? color.opacity(0.4) : .clear, radius: 6)
            .scaleEffect(isSelected ? 1.25 : 1.0)
            .animation(AppAnimation.spring, value: isSelected)
    }

    // MARK: - Pin Detail Card

    private func pinDetailCard(_ item: ExploreItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Type badge
                Text(typeLabel(item))
                    .font(.znEyebrow)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(typeColor(item))

                Spacer()

                Button {
                    withAnimation(AppAnimation.spring) {
                        selectedItem = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(item.localizedName(language: appState.language))
                .font(.cardHeadline)
                .foregroundStyle(.znInk)

            if let subtitle = itemSubtitle(item) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.znBody)
                    .lineLimit(2)
            }

            // Get directions button
            Button {
                openDirections(to: item)
            } label: {
                Label(appState.localized(en: "Get directions", de: "Route planen"), systemImage: "arrow.triangle.turn.up.right.diamond")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.znNavy)
                    .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    // MARK: - Legend

    private var legendBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendDot(color: .znTerracotta, label: appState.localized(en: "Activities", de: "Aktivitäten"))
            legendDot(color: .znNavy, label: appState.localized(en: "Events", de: "Events"))
            legendDot(color: .znPositive, label: appState.localized(en: "Deals", de: "Angebote"))
        }
        .font(.caption2)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func typeLabel(_ item: ExploreItem) -> String {
        switch item {
        case .activity: return appState.localized(en: "Activity", de: "Aktivität")
        case .event: return "Event"
        case .deal(let d, _): return appState.language == .en ? d.type.displayName : d.type.displayNameDE
        }
    }

    private func typeColor(_ item: ExploreItem) -> Color {
        switch item {
        case .activity: return .znTerracotta
        case .event: return .znNavy
        case .deal: return .znPositive
        }
    }

    private func itemSubtitle(_ item: ExploreItem) -> String? {
        switch item {
        case .activity(let a):
            return a.localizedDescription(language: appState.language)
        case .event(let e, _):
            return e.localizedDescription(language: appState.language)
        case .deal(let d, _):
            return d.localizedDescription(language: appState.language)
        }
    }

    private func openDirections(to item: ExploreItem) {
        let name = item.localizedName(language: appState.language)

        switch item {
        case .activity:
            // Activities have real coordinates — use them
            let coord = item.coordinate
            let placemark = MKPlacemark(coordinate: coord)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = name
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        case .event, .deal:
            // No real coordinates — search by name in Apple Maps
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?q=\(encoded)") {
                UIApplication.shared.open(url)
            }
        }
    }
}

#Preview {
    ExploreMapOverlay(items: [], city: .zurich, onCollapse: {})
        .environment(AppState())
}
