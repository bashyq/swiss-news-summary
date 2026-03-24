import SwiftUI
import CoreLocation
import MapKit

/// Category drill-down view showing items for a specific ExploreCategory.
///
/// Displays a photo hero header, a featured item card,
/// and accordion venue cards (vcard) below.
struct CategoryDetailView: View {
    @Environment(AppState.self) private var appState

    let category: ExploreCategory
    var viewModel: ExploreViewModel?
    private let staticItems: [ExploreItem]?
    let userLocation: CLLocation?

    /// Primary initializer — dynamic items from viewModel (refreshes on city change).
    init(category: ExploreCategory, viewModel: ExploreViewModel, userLocation: CLLocation?) {
        self.category = category
        self.viewModel = viewModel
        self.staticItems = nil
        self.userLocation = userLocation
    }

    /// Fallback initializer — static items (used in previews).
    init(category: ExploreCategory, items: [ExploreItem], userLocation: CLLocation?) {
        self.category = category
        self.viewModel = nil
        self.staticItems = items
        self.userLocation = userLocation
    }

    /// Items are computed dynamically from viewModel when available,
    /// so they update when the city changes.
    private var items: [ExploreItem] {
        if let viewModel {
            return viewModel.items(for: category, city: appState.city, language: appState.language)
        }
        return staticItems ?? []
    }

    @Environment(\.dismiss) private var dismiss
    @State private var expandedItemID: String?
    @State private var dealFilter: DealFilter = .all
    @State private var showMap: Bool = false
    @State private var mapPosition: MapCameraPosition = .automatic

    /// Whether this category supports map + city selector (location-based content)
    private var supportsMapAndCity: Bool {
        switch category {
        case .museums, .parks: return true
        case .restaurants, .events, .deals: return false
        }
    }

    /// Items filtered by the active deal filter (only applies to .deals category)
    private var filteredItems: [ExploreItem] {
        guard category == .deals, dealFilter != .all else { return items }
        return items.filter { item in
            guard case .deal(let d, _) = item else { return false }
            switch dealFilter {
            case .all: return true
            case .free: return d.type == .free
            case .deal: return d.type == .deal
            case .tip: return d.type == .tip
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sticky hero header
            heroHeader

            // Scrollable content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Map (collapsible, for location-based categories)
                        if supportsMapAndCity && showMap {
                            categoryMapView
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                                .padding(.horizontal)
                        }

                        // Featured card (first item)
                        if let featured = filteredItems.first {
                            featuredCard(featured)
                                .padding(.horizontal)
                        }

                        // Venue cards (vcard accordion)
                        if filteredItems.count > 1 {
                            VStack(spacing: 10) {
                                ForEach(Array(filteredItems.dropFirst())) { item in
                                    venueCard(item, proxy: proxy)
                                        .id(item.id)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if filteredItems.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hero Header

    private var mapToggleButton: some View {
        GlassButton(
            systemName: showMap ? "list.bullet" : "map"
        ) {
            withAnimation(AppAnimation.standardEase) {
                showMap.toggle()
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button row + glass action buttons
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                Spacer()

                if supportsMapAndCity {
                    HStack(spacing: 8) {
                        mapToggleButton
                        CityMenuButton()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Spacer(minLength: 0)

            // Title content — bottom-left
            VStack(alignment: .leading, spacing: 4) {
                Text(categoryEyebrow)
                    .font(.znEyebrow)
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.55))

                Text(appState.language == .en ? category.displayName : category.displayNameDE)
                    .font(.bannerTitle)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Label(
                        appState.localized(en: "\(filteredItems.count) venues", de: "\(filteredItems.count) Orte"),
                        systemImage: category.sfSymbol
                    )
                    .font(.znEyebrow)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.14))
                    .clipShape(Capsule())
                }
                .padding(.top, 2)

                // Deal type filter pills
                if category == .deals {
                    dealFilterPills
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 150)
        .background {
            ZStack {
                LinearGradient(
                    colors: category.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [
                        .black.opacity(0.2),
                        .clear,
                        .black.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(.container, edges: .top)
        }
    }

    private var dealFilterPills: some View {
        HStack(spacing: 8) {
            ForEach(DealFilter.allCases, id: \.self) { filter in
                let isSelected = dealFilter == filter
                let label = appState.language == .en ? filter.displayName : filter.displayNameDE
                let count = dealFilterCount(filter)

                Button {
                    withAnimation(AppAnimation.standardEase) {
                        dealFilter = filter
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(label)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        if let count, count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 18, height: 18)
                                .background(.white.opacity(isSelected ? 0.25 : 0.12))
                                .clipShape(Circle())
                                .contentTransition(.numericText())
                                .animation(.default, value: count)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.white.opacity(0.2) : .clear)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(isSelected ? 0.6 : 0.3), lineWidth: 1)
                    )
                }
                .sensoryFeedback(.selection, trigger: isSelected)
            }
        }
    }

    private func dealFilterCount(_ filter: DealFilter) -> Int? {
        let count: Int
        switch filter {
        case .all:
            count = items.count
        case .free:
            count = items.filter { if case .deal(let d, _) = $0 { return d.type == .free }; return false }.count
        case .deal:
            count = items.filter { if case .deal(let d, _) = $0 { return d.type == .deal }; return false }.count
        case .tip:
            count = items.filter { if case .deal(let d, _) = $0 { return d.type == .tip }; return false }.count
        }
        return count > 0 ? count : nil
    }

    private var categoryEyebrow: String {
        let typeName: String = switch category {
        case .museums: appState.localized(en: "Culture", de: "Kultur")
        case .parks: appState.localized(en: "Outdoors", de: "Draussen")
        case .restaurants: appState.localized(en: "Food & drink", de: "Essen & Trinken")
        case .events: appState.localized(en: "Family", de: "Familie")
        case .deals: appState.localized(en: "Featured", de: "Empfohlen")
        }
        let cityName = appState.city.localizedName(language: appState.language)
        return "\(typeName) · \(cityName)"
    }

    // MARK: - Featured Card

    private func featuredCard(_ item: ExploreItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Photo area
            ZStack(alignment: .bottomLeading) {
                // Try loading R2 photo for activities
                if let photoURL = photoURL(for: item) {
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            featuredPhotoFallback(item)
                        default:
                            featuredPhotoFallback(item)
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                    .frame(height: 160)
                    .clipped()
                } else {
                    featuredPhotoFallback(item)
                        .frame(height: 160)
                }

                // Badge
                Text(featuredBadgeLabel(item))
                    .font(.znEyebrow)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vcardBadgeColor(item))
                    .clipShape(Capsule())
                    .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.localizedName(language: appState.language))
                    .font(.cardHeadline)
                    .foregroundStyle(.znInk)

                if let subtitle = subtitleText(item) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.znBody)
                        .lineLimit(2)
                }

                // Metadata row: distance, price, kids badge
                HStack(spacing: 8) {
                    if let dist = distanceString(to: item) {
                        Label(dist, systemImage: "location")
                            .font(.caption2)
                            .foregroundStyle(.znMuted)
                    }

                    if let price = shortPrice(item) {
                        Text(price)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(price == appState.localized(en: "Free", de: "Gratis") ? .znPositive : .znBody)
                    }

                    if isKidsFriendly(item) {
                        Text(appState.localized(en: "Kids ok", de: "Kinderfreundlich"))
                            .font(.system(size: 9, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.znPositive)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.znPositive.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }

    // MARK: - Venue Card (vcard accordion)

    private func venueCard(_ item: ExploreItem, proxy: ScrollViewProxy) -> some View {
        let isExpanded = expandedItemID == item.id

        return VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                // Expanded: photo panel + content + buttons (matches ActivityCard)
                venueExpandedPhoto(item)
                venueExpandedContent(item)
                venueDetailPanel(item)
            } else {
                // Collapsed: compact face
                venueCompactFace(item)
            }
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.znBorder, lineWidth: 1)
        )
        .shadow(
            color: isExpanded ? AppShadow.cardExpanded.color : .clear,
            radius: isExpanded ? AppShadow.cardExpanded.radius : 0, x: 0, y: isExpanded ? AppShadow.cardExpanded.y : 0
        )
        .contentShape(Rectangle())
        .sensoryFeedback(.impact(weight: .light), trigger: expandedItemID)
        .onTapGesture {
            withAnimation(AppAnimation.spring) {
                expandedItemID = expandedItemID == item.id ? nil : item.id
            }
            if expandedItemID == item.id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { proxy.scrollTo(item.id, anchor: .top) }
                }
            }
        }
    }

    // MARK: - Venue Compact Face (collapsed)

    private func venueCompactFace(_ item: ExploreItem) -> some View {
        HStack(spacing: 0) {
            vcardPhoto(item)
                .padding(10)

            VStack(alignment: .leading, spacing: 4) {
                // Title + prominent open/closed badge
                HStack(spacing: 8) {
                    Text(item.localizedName(language: appState.language))
                        .font(.custom("PlayfairDisplay-SemiBold", size: 16))
                        .foregroundStyle(.znNavy)
                        .lineLimit(1)

                    if case .activity(let a) = item, a.openingHours != nil {
                        VenueStatusBadge(openingHours: a.openingHours, prominent: true)
                    }
                }

                if let subtitle = subtitleText(item) {
                    Text(subtitle)
                        .font(.system(size: 11.5, weight: .light))
                        .foregroundStyle(.znBody)
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                // Meta row: indoor/outdoor + distance
                HStack(spacing: 6) {
                    if case .activity(let a) = item {
                        Text(a.indoor
                            ? appState.localized(en: "Indoor", de: "Indoor")
                            : appState.localized(en: "Outdoor", de: "Outdoor"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.znNavy)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(Color.znNavy.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)

                    if let dist = distanceString(to: item) {
                        Text("↗ \(dist)")
                            .font(.system(size: 10))
                            .foregroundStyle(.znMuted)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.leading, 4)
            .padding(.trailing, 4)
            .padding(.vertical, 13)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.znChevron)
                .frame(width: 34)
        }
    }

    // MARK: - Venue Expanded Photo

    @ViewBuilder
    private func venueExpandedPhoto(_ item: ExploreItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let photoURL = photoURL(for: item) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .clipped()
                    default:
                        LinearGradient(
                            colors: [typeColor(item).opacity(0.3), Color.znSurface],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 150)
                    }
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [typeColor(item).opacity(0.3), Color.znSurface],
                        startPoint: .top, endPoint: .bottom
                    )
                    Image(systemName: categorySymbol(item))
                        .font(.system(size: 36))
                        .foregroundStyle(typeColor(item).opacity(0.5))
                }
                .frame(height: 150)
            }

            LinearGradient(
                colors: [.clear, Color.znSurface],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 80)

            Text(vcardBadgeLabel(item).uppercased())
                .font(.znEyebrow)
                .tracking(0.8)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.znNavy.opacity(0.82))
                .clipShape(Capsule())
                .padding(.leading, 14)
                .padding(.bottom, 62)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Venue Expanded Content

    private func venueExpandedContent(_ item: ExploreItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title + prominent status
            HStack(spacing: 8) {
                Text(item.localizedName(language: appState.language))
                    .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                    .foregroundStyle(Color.znNavy)
                    .fixedSize(horizontal: false, vertical: true)

                if case .activity(let a) = item, a.openingHours != nil {
                    VenueStatusBadge(openingHours: a.openingHours, prominent: true)
                }
            }
            .padding(.bottom, 6)

            if let desc = subtitleText(item) {
                Text(desc)
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color.znBody)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
            }

            // Quick Info row
            venueQuickInfo(item)
        }
        .padding(.top, 15)
        .padding(.horizontal, 18)
        .padding(.bottom, 13)
    }

    private func venueQuickInfo(_ item: ExploreItem) -> some View {
        VenueQuickInfoRow(items: {
            var items: [VenueQuickInfoRow.Item] = []
            if let duration = durationText(item) {
                items.append(.init(icon: "clock", label: appState.localized(en: "Duration", de: "Dauer"), value: duration))
            }
            if let dist = distanceString(to: item) {
                items.append(.init(icon: "location.fill", label: appState.localized(en: "Distance", de: "Entfernung"), value: dist))
            }
            if let price = priceText(item) {
                items.append(.init(icon: "banknote", label: appState.localized(en: "Price", de: "Preis"), value: price))
            }
            if case .activity(let a) = item,
               let todayHours = OpeningHoursParser.todayHours(from: a.openingHours) {
                items.append(.init(icon: "clock.badge", label: appState.localized(en: "Hours", de: "Zeiten"), value: todayHours))
            }
            return items
        }())
    }

    // MARK: - Vcard Photo

    private func vcardPhoto(_ item: ExploreItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let photoURL = photoURL(for: item) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 76, height: 76)
                            .clipped()
                    case .failure:
                        vcardPhotoFallback(item)
                    default:
                        Rectangle()
                            .fill(Color.znBorder.opacity(0.5))
                            .overlay { ProgressView().tint(.znMuted) }
                    }
                }
            } else {
                vcardPhotoFallback(item)
            }

            // Category badge
            Text(vcardBadgeLabel(item).uppercased())
                .font(.system(size: 7, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.znNavy.opacity(0.82))
                .clipShape(Capsule())
                .padding(4)
        }
        .frame(width: 76, height: 76)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func vcardPhotoFallback(_ item: ExploreItem) -> some View {
        ZStack {
            LinearGradient(
                colors: [typeColor(item).opacity(0.15), typeColor(item).opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: categorySymbol(item))
                .font(.system(size: 22))
                .foregroundStyle(typeColor(item).opacity(0.4))
        }
    }

    private func vcardBadgeLabel(_ item: ExploreItem) -> String {
        switch item {
        case .activity(let a):
            let cat = a.category.lowercased()
            if cat == "museums" || cat == "museum" { return appState.localized(en: "Museum", de: "Museum") }
            if cat == "parks" || cat == "playgrounds" { return appState.localized(en: "Park", de: "Park") }
            if cat == "animals" { return appState.localized(en: "Animals", de: "Tiere") }
            if cat == "transport" { return appState.localized(en: "Transport", de: "Transport") }
            return a.indoor ? appState.localized(en: "Indoor", de: "Indoor") : appState.localized(en: "Outdoor", de: "Outdoor")
        case .event: return appState.localized(en: "Event", de: "Event")
        case .deal(let d, _):
            return appState.language == .en ? d.type.displayName : d.type.displayNameDE
        }
    }

    private func featuredBadgeLabel(_ item: ExploreItem) -> String {
        switch item {
        case .deal(let d, _):
            return appState.language == .en ? d.type.displayName : d.type.displayNameDE
        default:
            return appState.localized(en: "Featured", de: "Empfohlen")
        }
    }

    private func vcardBadgeColor(_ item: ExploreItem) -> Color {
        switch item {
        case .activity, .event: return .znNavy
        case .deal(let d, _):
            switch d.type {
            case .free: return .znPositive
            case .deal: return .znNavy
            case .tip: return .znTerracotta
            }
        }
    }

    // MARK: - Expand Panel

    // MARK: - Venue Detail Panel (action buttons)

    @ViewBuilder
    private func venueDetailPanel(_ item: ExploreItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Directions — tinted (matches PlanSlotCard)
                Button {
                    openDirections(to: item)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(appState.localized(en: "Directions", de: "Route"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.znTerracotta)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.znTerracotta.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Plan → — tinted
                Button {
                    // TODO: anchor form for explore items
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 12))
                        Text(appState.localized(en: "Plan →", de: "Planen →"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.znNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.znNavy.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Website — tinted icon
                if let url = itemURL(item) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Image(systemName: "globe")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.znNavy)
                            .frame(width: 40, height: 40)
                            .background(Color.znNavy.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                // Heart — tinted icon
                Button {
                    toggleSave(item)
                } label: {
                    Image(systemName: isSaved(item) ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundStyle(isSaved(item) ? Color.znTerracotta : Color.znNavy)
                        .frame(width: 40, height: 40)
                        .background(isSaved(item) ? Color.znTerracotta.opacity(0.12) : Color.znNavy.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: isSaved(item))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Category Map

    private var categoryMapView: some View {
        let mapItems = filteredItems.filter { item in
            // Only show items with real coordinates (activities)
            if case .activity = item { return true }
            return false
        }

        return Map(position: $mapPosition) {
            // User location
            UserAnnotation()

            ForEach(mapItems) { item in
                Marker(
                    item.localizedName(language: appState.language),
                    systemImage: category == .museums ? "building.columns" : "leaf",
                    coordinate: item.coordinate
                )
                .tint(category == .museums ? .znNavy : .znTerracotta)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            if let loc = userLocation {
                mapPosition = .region(MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: category.sfSymbol)
                .font(.largeTitle)
                .foregroundStyle(.znMuted)
            Text(appState.localized(
                en: "Nothing here yet",
                de: "Noch nichts hier"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Photo Helpers

    /// R2 photo URL — only activities have photos via the /photo endpoint
    private func photoURL(for item: ExploreItem) -> URL? {
        guard case .activity(let a) = item,
              !a.id.hasPrefix("custom-"),
              a.category.lowercased() != "stayhome" else {
            return nil
        }
        return APIClient.shared.photoURL(for: a.id)
    }

    /// Gradient + icon fallback for featured card photo area
    private func featuredPhotoFallback(_ item: ExploreItem) -> some View {
        ZStack {
            LinearGradient(
                colors: [typeColor(item).opacity(0.25), Color.znNavy.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: categorySymbol(item))
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Helpers

    private func typeColor(_ item: ExploreItem) -> Color {
        switch item {
        case .activity: return .znTerracotta
        case .event: return .znNavy
        case .deal: return .znPositive
        }
    }

    private func categorySymbol(_ item: ExploreItem) -> String {
        switch item {
        case .activity(let a):
            return a.indoor ? "house.fill" : "leaf.fill"
        case .event: return "calendar"
        case .deal: return "tag.fill"
        }
    }

    private func subtitleText(_ item: ExploreItem) -> String? {
        switch item {
        case .activity(let a): return a.localizedDescription(language: appState.language)
        case .event(let e, _): return e.localizedDescription(language: appState.language)
        case .deal(let d, _): return d.localizedDescription(language: appState.language)
        }
    }

    /// Price string — activities have free-text price, deals show type badge
    private func priceText(_ item: ExploreItem) -> String? {
        switch item {
        case .activity(let a):
            if a.free == true {
                return appState.localized(en: "Free", de: "Gratis")
            }
            return a.localizedPrice(language: appState.language)
        case .event(let e, _):
            return e.free ? appState.localized(en: "Free", de: "Gratis") : nil
        case .deal(let d, _):
            return d.type == .free ? appState.localized(en: "Free", de: "Gratis") : nil
        }
    }

    /// Short price for the collapsed card meta row — extracts "CHF X" from longer strings
    /// Deals don't show a price pill because the badge already conveys the type (Free/Deal/Tip).
    private func shortPrice(_ item: ExploreItem) -> String? {
        // Deals use the badge for type — no separate price pill needed
        if case .deal = item { return nil }
        guard let price = priceText(item) else { return nil }
        let free = appState.localized(en: "Free", de: "Gratis")
        if price == free { return free }
        // Extract just "CHF X" from strings like "CHF 10 adults, kids under 16 free"
        if price.hasPrefix("CHF") {
            let parts = price.components(separatedBy: " ")
            if parts.count >= 2 {
                return "\(parts[0]) \(parts[1])"
            }
        }
        return price
    }

    /// Whether the item is explicitly kid-friendly
    private func isKidsFriendly(_ item: ExploreItem) -> Bool {
        switch item {
        case .activity(let a):
            return !a.ageRange.isEmpty
        case .event(let e, _):
            return e.toddlerFriendly
        case .deal:
            return false
        }
    }

    private func distanceString(to item: ExploreItem) -> String? {
        guard let location = userLocation else { return nil }
        let itemLoc = CLLocation(latitude: item.coordinate.latitude, longitude: item.coordinate.longitude)
        let meters = location.distance(from: itemLoc)
        if meters < 1000 {
            return "\(Int(meters))m"
        }
        return String(format: "%.1f km", meters / 1000)
    }

    /// Age range text for the detail grid
    private func agesText(_ item: ExploreItem) -> String? {
        switch item {
        case .activity(let a):
            return a.ageRange.isEmpty ? nil : a.ageRange
        case .event(let e, _):
            return e.toddlerFriendly ? appState.localized(en: "Toddler-friendly", de: "Kleinkindgerecht") : nil
        case .deal:
            return nil
        }
    }

    /// Duration text for the detail grid
    private func durationText(_ item: ExploreItem) -> String? {
        switch item {
        case .activity(let a):
            return a.duration.isEmpty ? nil : a.duration
        case .event:
            return nil
        case .deal:
            return nil
        }
    }

    /// URL for website/booking
    private func itemURL(_ item: ExploreItem) -> URL? {
        switch item {
        case .activity(let a):
            guard let urlStr = a.url else { return nil }
            return URL(string: urlStr)
        case .event(let e, _):
            guard let urlStr = e.url else { return nil }
            return URL(string: urlStr)
        case .deal(let d, _):
            guard let urlStr = d.url else { return nil }
            return URL(string: urlStr)
        }
    }

    /// Open Apple Maps directions.
    /// Activities have real coordinates so we pass coords + name.
    /// Events/deals only have fake offsets from city center, so we search by name only.
    private func openDirections(to item: ExploreItem) {
        let name = item.localizedName(language: appState.language)
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString: String
        switch item {
        case .activity:
            let coord = item.coordinate
            urlString = "https://maps.apple.com/directions?destination=\(coord.latitude),\(coord.longitude)&mode=walking"
        case .event, .deal:
            // No real coordinates — let Apple Maps find the place by name
            urlString = "https://maps.apple.com/?q=\(encodedName)"
        }

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    /// Whether this activity is saved
    private func isSaved(_ item: ExploreItem) -> Bool {
        guard case .activity(let a) = item else { return false }
        return appState.savedActivityIDs.contains(a.id)
    }

    /// Toggle save state
    private func toggleSave(_ item: ExploreItem) {
        guard case .activity(let a) = item else { return }
        if appState.savedActivityIDs.contains(a.id) {
            appState.savedActivityIDs.remove(a.id)
        } else {
            appState.savedActivityIDs.insert(a.id)
        }
    }

    /// Share URL for the item
    private func shareURL(_ item: ExploreItem) -> URL {
        if let url = itemURL(item) { return url }
        // Fallback to Apple Maps location
        let coord = item.coordinate
        return URL(string: "https://maps.apple.com/?ll=\(coord.latitude),\(coord.longitude)")!
    }
}

#Preview {
    let sampleActivities = [
        Activity(id: "landesmuseum", name: "Landesmuseum", nameDE: "Landesmuseum", description: "Swiss cultural history from prehistory to the present. Interactive exhibits throughout.", descriptionDE: "Schweizer Kulturgeschichte von der Urzeit bis heute.", indoor: true, ageRange: "5+ years", duration: "1-2 hours", price: "CHF 10 · under 16 free", priceDE: "CHF 10 · unter 16 gratis", url: "https://www.nationalmuseum.ch", lat: 47.3790, lon: 8.5400, category: "museums", minAge: 5, maxAge: 12, season: nil, free: false, recurring: nil, stayHome: nil, availableMonths: nil, subcategory: nil, materials: nil, materialsDE: nil, addedDate: nil, suggestibility: nil),
        Activity(id: "kunsthaus", name: "Kunsthaus Zürich", nameDE: "Kunsthaus Zürich", description: "One of Switzerland's most important art museums with works from the Middle Ages to contemporary art.", descriptionDE: "Eines der wichtigsten Kunstmuseen der Schweiz.", indoor: true, ageRange: "3-12 years", duration: "1-3 hours", price: "CHF 23 · under 17 free", priceDE: "CHF 23 · unter 17 gratis", url: "https://www.kunsthaus.ch", lat: 47.3703, lon: 8.5486, category: "museums", minAge: 3, maxAge: 12, season: nil, free: false, recurring: nil, stayHome: nil, availableMonths: nil, subcategory: nil, materials: nil, materialsDE: nil, addedDate: nil, suggestibility: nil),
        Activity(id: "zoo-zurich", name: "Zoo Zürich", nameDE: "Zoo Zürich", description: "Award-winning zoo with Masoala rainforest, elephant park, and penguins. Great for toddlers.", descriptionDE: "Preisgekrönter Zoo mit Masoala-Regenwald.", indoor: false, ageRange: "2-5 years", duration: "2-4 hours", price: "CHF 29 · kids under 6 free", priceDE: "CHF 29 · Kinder unter 6 gratis", url: "https://www.zoo.ch", lat: 47.3849, lon: 8.5743, category: "animals", minAge: 2, maxAge: 5, season: nil, free: false, recurring: nil, stayHome: nil, availableMonths: nil, subcategory: nil, materials: nil, materialsDE: nil, addedDate: nil, suggestibility: "oncePer30Days"),
    ]
    let items = sampleActivities.map { ExploreItem.activity($0) }

    NavigationStack {
        CategoryDetailView(
            category: .museums,
            items: items,
            userLocation: CLLocation(latitude: 47.3769, longitude: 8.5417)
        )
    }
    .environment(AppState())
}
