import SwiftUI
import MapKit

/// Map-first exploration view combining activities, events, and deals on a single map.
struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ExploreViewModel()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedItem: ExploreItem?
    @State private var showFullMap = false

    var body: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                // Hero + filter are always visible
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroBanner
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // Filter bar
                        filterBar
                            .padding(.top, 10)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                if showFullMap {
                    // Full-screen map mode
                    fullMapSection(scrollProxy: scrollProxy)
                        .padding(.top, 8)
                } else {
                    // Map + card list mode
                    ScrollView {
                        VStack(spacing: 0) {
                            mapSection(scrollProxy: scrollProxy)
                                .padding(.top, 8)

                            cardList
                                .padding(.top, 12)
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: "\(appState.city.rawValue)-\(appState.language.rawValue)") {
            await viewModel.loadData(city: appState.city, language: appState.language)
            resetCamera()
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        HeroBanner(style: .explore, title: appState.localized(en: "Explore", de: "Entdecken")) {
            HStack(spacing: 14) {
                mapToggleButton
                cityMenu
            }
        }
    }

    private var cityMenu: some View {
        Menu {
            ForEach(City.allCases) { city in
                Button {
                    appState.city = city
                } label: {
                    HStack {
                        Text(city.localizedName(language: appState.language))
                        if city == appState.city {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "building.2")
        }
    }

    private var mapToggleButton: some View {
        Button {
            withAnimation(AppAnimation.standardEase) {
                showFullMap.toggle()
            }
        } label: {
            Image(systemName: showFullMap ? "list.bullet" : "map")
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExploreFilter.allCases, id: \.self) { filter in
                    let isSelected = viewModel.filter == filter
                    Button {
                        withAnimation(AppAnimation.spring) {
                            viewModel.filter = filter
                        }
                    } label: {
                        Label(
                            appState.language == .en ? filter.displayName : filter.displayNameDE,
                            systemImage: filter.sfSymbol
                        )
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            isSelected
                            ? AnyShapeStyle(LinearGradient.brand)
                            : AnyShapeStyle(Color(.secondarySystemBackground))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                        .scaleEffect(isSelected ? AppAnimation.selectedScale : 1.0)
                    }
                    .sensoryFeedback(.selection, trigger: isSelected)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Full Map

    private func fullMapSection(scrollProxy: ScrollViewProxy) -> some View {
        let items = viewModel.filteredItems(city: appState.city, language: appState.language)

        return Map(position: $cameraPosition) {
            ForEach(items) { item in
                Annotation(item.localizedName(language: appState.language), coordinate: item.coordinate) {
                    annotationView(for: item)
                        .onTapGesture {
                            withAnimation(AppAnimation.spring) {
                                selectedItem = item
                            }
                        }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(alignment: .bottomLeading) {
            legendBar
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(12)
        }
        .overlay(alignment: .bottom) {
            // Selected item card overlay
            if let selected = selectedItem {
                ExploreCardView(item: selected, language: appState.language, isSelected: true)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Map

    private func mapSection(scrollProxy: ScrollViewProxy) -> some View {
        let items = viewModel.filteredItems(city: appState.city, language: appState.language)

        return Map(position: $cameraPosition) {
            ForEach(items) { item in
                Annotation(item.localizedName(language: appState.language), coordinate: item.coordinate) {
                    annotationView(for: item)
                        .onTapGesture {
                            withAnimation(AppAnimation.spring) {
                                selectedItem = item
                            }
                            // Scroll the list to the tapped item's card
                            withAnimation {
                                scrollProxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: AppSpacing.mapHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(alignment: .bottom) {
            // Gradient fade at bottom
            LinearGradient(
                colors: [.clear, Color(.systemBackground).opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 12
                )
            )
        }
        .padding(.horizontal)
    }

    private func annotationView(for item: ExploreItem) -> some View {
        let isSelected = selectedItem?.id == item.id

        let color: Color = switch item {
        case .activity: .orange
        case .event: .purple
        case .deal: .teal
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

    // MARK: - Card List

    private var cardList: some View {
        let items = viewModel.filteredItems(city: appState.city, language: appState.language)

        return LazyVStack(spacing: 10) {
            if viewModel.isLoading && items.isEmpty {
                ProgressView()
                    .padding(.top, 40)
            } else if items.isEmpty {
                emptyState
            } else {
                // Legend
                legendBar

                ForEach(items) { item in
                    ExploreCardView(item: item, language: appState.language, isSelected: selectedItem?.id == item.id)
                        .id(item.id)
                        .onTapGesture {
                            withAnimation(AppAnimation.spring) {
                                selectedItem = item
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: item.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                ))
                            }
                        }
                        .sensoryFeedback(.selection, trigger: selectedItem?.id == item.id)
                }
            }
        }
    }

    private var legendBar: some View {
        HStack(spacing: 16) {
            legendDot(color: .orange, label: appState.localized(en: "Activities", de: "Aktivitäten"))
            legendDot(color: .purple, label: appState.localized(en: "Events", de: "Events"))
            legendDot(color: .teal, label: appState.localized(en: "Deals", de: "Angebote"))
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            EmojiScene(["🗺️", "🔍", "📍"], size: 28)
            Text(appState.localized(en: "Nothing to explore yet", de: "Noch nichts zu entdecken"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    // MARK: - Helpers

    private func resetCamera() {
        let center = appState.city.coordinate
        cameraPosition = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        ))
    }
}

// MARK: - Explore Card

struct ExploreCardView: View {
    let item: ExploreItem
    let language: AppLanguage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(itemColor)
                .frame(width: 4)

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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(isSelected ? itemColor.opacity(0.5) : .clear, lineWidth: 2)
        )
        .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, x: AppShadow.subtle.x, y: AppShadow.subtle.y)
    }

    private var itemColor: Color {
        switch item {
        case .activity: return .orange
        case .event: return .purple
        case .deal: return .teal
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
            return a.indoor
                ? (language == .en ? "Indoor" : "Indoor")
                : (language == .en ? "Outdoor" : "Outdoor")
        case .event(let e, _):
            return e.startDate == e.endDate ? e.startDate : "\(e.startDate) – \(e.endDate)"
        case .deal(let d, _):
            return d.localizedDescription(language: language)
        }
    }
}

#Preview {
    NavigationStack {
        ExploreView()
    }
    .environment(AppState())
}
