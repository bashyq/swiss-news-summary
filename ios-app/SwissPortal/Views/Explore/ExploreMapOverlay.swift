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
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, Color.znCream.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .allowsHitTesting(false)
        }
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
        VStack(alignment: .leading, spacing: 0) {
            // Photo for activities
            if case .activity(let a) = item,
               !a.id.hasPrefix("custom-"),
               a.category.lowercased() != "stayhome",
               let photoURL = APIClient.shared.photoURL(for: a.id) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    case .failure:
                        photoFallback(item)
                    default:
                        photoFallback(item)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(AppAnimation.spring) {
                            selectedItem = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.3))
                    }
                    .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                // Type badge + close (if no photo)
                HStack {
                    Text(typeLabel(item))
                        .font(.znEyebrow)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(typeColor(item))

                    Spacer()

                    if !itemHasPhoto(item) {
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

                // Opening hours
                if let hours = itemOpeningHours(item) {
                    HStack(spacing: 4) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 10))
                        Text(hours)
                            .font(.caption2)
                    }
                    .foregroundStyle(.znMuted)
                }

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        openDirections(to: item)
                    } label: {
                        Label(appState.localized(en: "Directions", de: "Route"), systemImage: "arrow.triangle.turn.up.right.diamond")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.znNavy)
                            .clipShape(Capsule())
                    }

                    if let url = itemWebsiteURL(item) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label(appState.localized(en: "Website", de: "Webseite"), systemImage: "safari")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.znNavy)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.znNavy.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private func photoFallback(_ item: ExploreItem) -> some View {
        LinearGradient(
            colors: [typeColor(item).opacity(0.3), Color.znNavy.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 120)
        .overlay {
            Image(systemName: itemSymbol(item))
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func itemHasPhoto(_ item: ExploreItem) -> Bool {
        if case .activity(let a) = item,
           !a.id.hasPrefix("custom-"),
           a.category.lowercased() != "stayhome" {
            return true
        }
        return false
    }

    private func itemSymbol(_ item: ExploreItem) -> String {
        switch item {
        case .activity: return "mappin.circle.fill"
        case .event: return "star.circle.fill"
        case .deal: return "tag.circle.fill"
        }
    }

    private func itemOpeningHours(_ item: ExploreItem) -> String? {
        if case .activity(let a) = item {
            return a.localizedOpeningHours(language: appState.language)
        }
        return nil
    }

    private func itemWebsiteURL(_ item: ExploreItem) -> URL? {
        let urlString: String? = switch item {
        case .activity(let a): a.url
        case .event(let e, _): e.url
        case .deal(let d, _): d.url
        }
        guard let str = urlString, let url = URL(string: str) else { return nil }
        return url
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
