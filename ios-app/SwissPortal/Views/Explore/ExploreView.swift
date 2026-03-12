import SwiftUI
import MapKit

/// Explore view — hero with filters, mini map, near-you chips, browse-by-type grid.
struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @Binding var path: NavigationPath
    @State private var viewModel = ExploreViewModel()
    @State private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showFullMap = false
    @State private var mapInitialSelection: ExploreItem?

    var body: some View {
        VStack(spacing: 0) {
            // Header — full hero in list mode, compact bar in map mode
            ExploreHeroBanner(
                filter: $viewModel.filter,
                showFullMap: showFullMap,
                onMapToggle: {
                    withAnimation(AppAnimation.spring) {
                        showFullMap.toggle()
                    }
                }
            )

            if showFullMap {
                // Inline map — fills remaining space, tab bar stays visible
                ExploreMapOverlay(
                    items: viewModel.filteredItems(city: appState.city, language: appState.language),
                    city: appState.city,
                    onCollapse: {
                        withAnimation(AppAnimation.spring) {
                            showFullMap = false
                            mapInitialSelection = nil
                        }
                    },
                    initialSelection: mapInitialSelection
                )
            } else {
                // List content
                ScrollView {
                    VStack(spacing: 0) {
                        // Mini map — "Browse by map"
                        miniMapSection
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // Loading indicator
                        if viewModel.isLoading && viewModel.activitiesData == nil {
                            ProgressView()
                                .padding(.top, 20)
                        } else {
                            // Near you section
                            NearYouSection(
                                items: nearYouItems,
                                userLocation: locationManager.location,
                                onItemTap: { item in
                                    mapInitialSelection = item
                                    withAnimation(AppAnimation.spring) {
                                        showFullMap = true
                                    }
                                }
                            )

                            // Browse by type
                            BrowseByTypeSection(
                                countForCategory: { category in
                                    viewModel.count(for: category, city: appState.city)
                                },
                                onRestaurantsTap: {
                                    path.append("lunch")
                                }
                            )
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: "\(appState.city.rawValue)-\(appState.language.rawValue)") {
            await viewModel.loadData(city: appState.city, language: appState.language)
            resetCamera()
            locationManager.requestLocation()
        }
        .onChange(of: appState.tabRetapCount) {
            if showFullMap {
                withAnimation(AppAnimation.spring) {
                    showFullMap = false
                }
            }
        }
        .navigationDestination(for: ExploreCategory.self) { category in
            if category == .events {
                EventsView(showHeroHeader: true)
            } else {
                CategoryDetailView(
                    category: category,
                    items: viewModel.items(for: category, city: appState.city, language: appState.language),
                    userLocation: locationManager.location
                )
            }
        }
        .navigationDestination(for: String.self) { route in
            if route == "lunch" {
                LunchView()
            }
        }
    }

    // MARK: - Mini Map

    private var miniMapSection: some View {
        let items = viewModel.filteredItems(city: appState.city, language: appState.language)

        return VStack(spacing: 10) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text(appState.localized(en: "Browse by map", de: "Karte durchsuchen"))
                    .font(.sectionHeadline)
                    .foregroundStyle(.znInk)
                Spacer()
                Button {
                    withAnimation(AppAnimation.spring) {
                        showFullMap = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(appState.localized(en: "Expand", de: "Erweitern"))
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.znTerracotta)
                }
            }

            // Map card
            Button {
                withAnimation(AppAnimation.spring) {
                    showFullMap = true
                }
            } label: {
                ZStack(alignment: .bottom) {
                    ZStack {
                        Map(position: $cameraPosition, interactionModes: []) {
                            ForEach(items) { item in
                                Annotation("", coordinate: item.coordinate) {
                                    miniAnnotation(for: item)
                                }
                            }
                        }
                        .mapStyle(.standard(pointsOfInterest: .excludingAll))

                        // Dark navy tint overlay to match mockup aesthetic
                        Color(red: 0.10, green: 0.15, blue: 0.21)
                            .opacity(0.52)
                            .allowsHitTesting(false)
                    }
                    .frame(height: AppSpacing.miniMapHeight)
                    .allowsHitTesting(false)

                    // Bottom bar: legend left, "Full map" pill right
                    HStack(alignment: .center) {
                        // Legend
                        HStack(spacing: 9) {
                            legendDot(color: .znTerracotta, label: appState.localized(en: "Activities", de: "Aktivitäten"))
                            legendDot(color: .znPositive, label: appState.localized(en: "Deals", de: "Angebote"))
                        }

                        Spacer()

                        // "Full map" pill
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9))
                            Text(appState.localized(en: "Full map", de: "Vollkarte"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.znNavy.opacity(0.8))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                        .stroke(Color.znBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func miniAnnotation(for item: ExploreItem) -> some View {
        let color: Color = switch item {
        case .activity: .znTerracotta
        case .event: .znNavy
        case .deal: .znPositive
        }
        return VStack(spacing: 0) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 4.4, height: 4.4)
                )
                .shadow(color: color.opacity(0.35), radius: 3, y: 1)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    // MARK: - Near You Items

    private var nearYouItems: [ExploreItem] {
        guard let location = locationManager.location else { return [] }
        return viewModel.nearYouItems(
            location: location,
            city: appState.city,
            language: appState.language,
            limit: 8
        )
    }

    // MARK: - Helpers

    private func resetCamera() {
        let center = appState.city.coordinate
        cameraPosition = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        ))
    }
}

// MARK: - Explore Card (used in map overlay)

struct ExploreCardView: View {
    let item: ExploreItem
    let language: AppLanguage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(itemColor)
                .frame(width: AppSpacing.borderStripWidth)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: itemSymbol)
                        .foregroundStyle(itemColor)
                        .font(.caption)
                    Text(itemTypeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(itemColor)
                        .textCase(.uppercase)
                }

                Text(item.localizedName(language: language))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                if let subtitle = itemSubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(isSelected ? itemColor.opacity(0.5) : .clear, lineWidth: 2)
        )
        .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, x: AppShadow.subtle.x, y: AppShadow.subtle.y)
    }

    private var itemColor: Color {
        switch item {
        case .activity: return .znTerracotta
        case .event: return .znNavy
        case .deal: return .znPositive
        }
    }

    private var itemSymbol: String {
        switch item {
        case .activity: return "sparkles"
        case .event: return "calendar"
        case .deal: return "tag"
        }
    }

    private var itemTypeLabel: String {
        switch item {
        case .activity: return language == .en ? "Activity" : "Aktivität"
        case .event: return "Event"
        case .deal(let d, _):
            return language == .en ? d.type.displayName : d.type.displayNameDE
        }
    }

    private var itemSubtitle: String? {
        switch item {
        case .activity(let a):
            return a.indoor ? "Indoor" : "Outdoor"
        case .event(let e, _):
            return e.startDate == e.endDate ? e.startDate : "\(e.startDate) – \(e.endDate)"
        case .deal(let d, _):
            return d.localizedDescription(language: language)
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    NavigationStack(path: $path) {
        ExploreView(path: $path)
    }
    .environment(AppState())
}
