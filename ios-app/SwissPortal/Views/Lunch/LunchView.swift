import SwiftUI
import CoreLocation

/// The main Lunch view — restaurant recommendations with map, list, and "Surprise me!" feature.
///
/// Displays a filterable list (or map) of nearby lunch spots fetched from the worker API.
/// Users can save favorites, rate restaurants, toggle between map/list, and get a random pick.
struct LunchView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(ToastManager.self) private var toastManager

    @State private var viewModel = LunchViewModel()
    @State private var surpriseSpot: LunchSpot?
    @State private var showAddSheet = false
    @State private var focusedSpot: LunchSpot?
    @State private var expandedSpotID: String?
    @State private var showSortSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .navigationBarHidden(true)
            .task(id: "\(appState.city.id)-\(appState.language)") {
                await viewModel.loadLunch(
                    city: appState.city,
                    language: appState.language
                )
            }
            .onChange(of: viewModel.activeToggles) { oldToggles, newToggles in
                if newToggles.contains(.nearMe) {
                    locationManager.requestLocation()
                }
                // Smart default: switch sort when Near Me toggled
                let wasNearMe = oldToggles.contains(.nearMe)
                let isNearMe = newToggles.contains(.nearMe)
                if isNearMe && !wasNearMe {
                    viewModel.sortOrder = .nearest
                } else if !isNearMe && wasNearMe && viewModel.sortOrder == .nearest {
                    viewModel.sortOrder = .topRated
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddRestaurantSheet()
            }
            .sheet(item: $surpriseSpot) { spot in
                LunchSurpriseSheet(
                    spot: spot,
                    onTryAnother: pickSurprise,
                    onSave: {
                        appState.toggleSavedLunch(spot.id)
                        let wasSaved = appState.savedLunchIDs.contains(spot.id)
                        toastManager.show(
                            appState.localized(en: wasSaved ? "Saved" : "Removed", de: wasSaved ? "Gespeichert" : "Entfernt"),
                            type: .success
                        )
                    },
                    isSaved: appState.savedLunchIDs.contains(spot.id)
                )
                .presentationDetents([.fraction(0.7), .large])
            }
            .sheet(isPresented: $showSortSheet) {
                LunchSortSheet(
                    selectedSort: $viewModel.sortOrder,
                    language: appState.language
                )
                .presentationDetents([.height(280)])
            }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "Lunch", de: "Mittagessen")
    }

    // MARK: - Glass Buttons (frosted circles matching other heroes)

    private func glassButton(
        systemName: String,
        size: CGFloat = 36,
        iconSize: CGFloat = 16,
        radius: CGFloat = 10,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: radius))
        }
    }

    private var cityMenuButton: some View {
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
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var mapToggleButton: some View {
        glassButton(
            systemName: viewModel.showMap ? "list.bullet" : "map"
        ) {
            withAnimation(AppAnimation.standardEase) {
                viewModel.showMap.toggle()
            }
        }
    }

    private var addButton: some View {
        glassButton(systemName: "plus") {
            showAddSheet = true
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button row
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            // Title row + icon buttons
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    // Eyebrow
                    Text(heroEyebrow)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))

                    // Title
                    Text(navigationTitle)
                        .font(.custom("Playfair", size: 28))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    addButton
                    mapToggleButton
                    cityMenuButton
                }
            }

            // Filter pills inside hero (matching Activities/Explore style)
            heroFilterPills
                .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy
                    .ignoresSafeArea(.container, edges: .top)
                RadialGradient(
                    colors: [Color.znTerracotta.opacity(0.22), .clear],
                    center: UnitPoint(x: 1.2, y: -0.3),
                    startRadius: 0,
                    endRadius: 220
                )
                cutlerySkyline
                    .frame(width: 200, height: 110)
                    .opacity(0.09)
            }
        }
    }

    // MARK: - Hero Filter Pills (white-on-transparent, matching Activities)

    private var heroFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Toggle pills (multi-select)
                ForEach(LunchToggle.allCases) { toggle in
                    let isSelected = viewModel.activeToggles.contains(toggle)
                    let label = appState.language == .en ? toggle.displayName : toggle.displayNameDE

                    Button {
                        withAnimation(AppAnimation.standardEase) {
                            if viewModel.activeToggles.contains(toggle) {
                                viewModel.activeToggles.remove(toggle)
                            } else {
                                viewModel.activeToggles.insert(toggle)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: toggle.sfSymbol)
                                .font(.system(size: 11))
                            Text(label)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
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

                // Cuisine dropdown
                heroCuisineMenu
            }
        }
    }

    private var heroCuisineMenu: some View {
        Menu {
            ForEach(CuisineFilter.allCases) { cuisine in
                Button {
                    withAnimation(AppAnimation.standardEase) {
                        viewModel.cuisineFilter = cuisine
                    }
                } label: {
                    HStack {
                        Text(appState.language == .en ? cuisine.displayName : cuisine.displayNameDE)
                        if viewModel.cuisineFilter == cuisine {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            let isActive = viewModel.cuisineFilter != .all
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 11))
                Text(appState.language == .en
                     ? viewModel.cuisineFilter.displayName
                     : viewModel.cuisineFilter.displayNameDE)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.white.opacity(0.2) : .clear)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(isActive ? 0.6 : 0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Cutlery Skyline Canvas

    private var cutlerySkyline: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let white = Color.white

            // Fork (left)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.20, y: h * 0.09))
                p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.73))
            }, with: .color(white), lineWidth: 2)
            // Fork tines
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.18, y: h * 0.09))
                p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.33))
            }, with: .color(white), lineWidth: 1.5)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.22, y: h * 0.09))
                p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.33))
            }, with: .color(white), lineWidth: 1.5)
            // Fork neck curve
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.18, y: h * 0.33))
                p.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.33),
                               control: CGPoint(x: w * 0.20, y: h * 0.40))
            }, with: .color(white), lineWidth: 1.5)

            // Knife (center-left)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.29, y: h * 0.09))
                p.addLine(to: CGPoint(x: w * 0.29, y: h * 0.73))
            }, with: .color(white), lineWidth: 2)
            // Knife blade
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.29, y: h * 0.09))
                p.addQuadCurve(to: CGPoint(x: w * 0.29, y: h * 0.38),
                               control: CGPoint(x: w * 0.33, y: h * 0.27))
            }, with: .color(white), lineWidth: 1.5)

            // Spoon (center)
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: w * 0.38, y: h * 0.25))
                p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.73))
            }, with: .color(white), lineWidth: 2)
            // Spoon bowl
            let spoonRect = CGRect(x: w * 0.345, y: h * 0.09, width: w * 0.07, height: h * 0.18)
            ctx.stroke(Path(ellipseIn: spoonRect), with: .color(white), lineWidth: 1.5)

            // City buildings (right side)
            ctx.fill(Path(CGRect(x: w * 0.50, y: h * 0.36, width: w * 0.07, height: h * 0.64)), with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.60, y: h * 0.50, width: w * 0.09, height: h * 0.50)), with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.72, y: h * 0.27, width: w * 0.05, height: h * 0.73)), with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.80, y: h * 0.45, width: w * 0.11, height: h * 0.55)), with: .color(white))
            ctx.fill(Path(CGRect(x: w * 0.94, y: h * 0.38, width: w * 0.06, height: h * 0.62)), with: .color(white))
        }
    }

    private var heroEyebrow: String {
        let categoryName = appState.localized(en: "Restaurants", de: "Restaurants")
        let cityName = appState.city.localizedName(language: appState.language)
        return "\(categoryName) · \(cityName)"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.lunchData == nil {
            ScrollView {
                VStack(spacing: 12) {
                    heroBanner
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonLunchCard()
                    }
                    .padding(.horizontal)
                }
            }
        } else if let error = viewModel.error, viewModel.lunchData == nil {
            VStack(spacing: 0) {
                heroBanner
                ErrorView(message: error) {
                    Task {
                        await viewModel.loadLunch(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                }
            }
        } else {
            lunchContent
        }
    }

    // MARK: - Lunch Content

    private var lunchContent: some View {
        let spots = currentSpots

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 0. Hero banner with title + filters + skyline
                heroBanner

                // 1. Results count + sort row
                resultsRow(spots: spots)

                // 2. Inline loading indicator for background refresh
                if viewModel.isLoading && viewModel.lunchData != nil {
                    InlineLoadingView()
                        .padding(.top, 4)
                }

                // 3. Map or list
                if viewModel.showMap {
                    LunchMapView(
                        spots: spots,
                        city: appState.city,
                        language: appState.language,
                        userFocusLocation: viewModel.activeToggles.contains(.nearMe) ? locationManager.location : nil,
                        focusedSpot: $focusedSpot
                    )
                    .frame(height: AppSpacing.mapHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // 4. Spot list
                spotList
            }

            // 5. "Surprise me!" floating button
            surpriseMeButton
                .padding(.bottom, 16)
        }
    }

    // MARK: - Results Row

    private func resultsRow(spots: [LunchSpot]) -> some View {
        let total = spots.count
        let displayed = viewModel.displaySpots(from: spots).count

        return HStack {
            Group {
                if displayed < total {
                    Text(appState.localized(
                        en: "\(displayed) of \(total) results",
                        de: "\(displayed) von \(total) Ergebnisse"
                    ))
                } else {
                    Text(appState.localized(
                        en: "\(total) results",
                        de: "\(total) Ergebnisse"
                    ))
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.znMuted)
            .contentTransition(.numericText())
            .animation(.default, value: total)

            Spacer()

            // Sort button
            Button {
                showSortSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 12))
                    Text(appState.language == .en
                         ? viewModel.sortOrder.displayName
                         : viewModel.sortOrder.displayNameDE)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.znNavy)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Spot List

    private var spotList: some View {
        let allSpots = currentSpots
        let displayedSpots = viewModel.displaySpots(from: allSpots)
        let isTruncated = displayedSpots.count < allSpots.count

        return Group {
            if allSpots.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(displayedSpots) { spot in
                                LunchCard(
                                    spot: spot,
                                    language: appState.language,
                                    location: locationManager.location,
                                    expandedID: $expandedSpotID,
                                    onTap: {
                                        withAnimation(AppAnimation.standardEase) {
                                            viewModel.showMap = true
                                        }
                                        focusedSpot = spot
                                    }
                                )
                                .id(spot.id)
                            }

                            if isTruncated {
                                Button {
                                    viewModel.showingAll = true
                                } label: {
                                    Text(appState.localized(
                                        en: "Show all \(allSpots.count) restaurants",
                                        de: "Alle \(allSpots.count) Restaurants anzeigen"
                                    ))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.brand)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.brand.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                                }
                                .buttonStyle(.plain)
                            }

                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 80) // Space for floating button
                    }
                    .refreshable {
                        await viewModel.loadLunch(
                            city: appState.city,
                            language: appState.language
                        )
                    }
                    .onChange(of: expandedSpotID) { _, newID in
                        if let newID {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation {
                                    proxy.scrollTo(newID, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Current Spots

    private var currentSpots: [LunchSpot] {
        var spots = viewModel.filteredSpots(
            savedIDs: appState.savedLunchIDs,
            userLocation: locationManager.location
        )

        switch viewModel.sortOrder {
        case .nearest:
            if let userLocation = locationManager.location {
                spots.sort { $0.distance(from: userLocation) < $1.distance(from: userLocation) }
            }
        case .topRated:
            // Sort by rating (highest first), unrated spots sink to the bottom
            spots.sort { a, b in
                let ratingA = a.rating ?? 0
                let ratingB = b.rating ?? 0
                if ratingA != ratingB { return ratingA > ratingB }
                return (a.ratingCount ?? 0) > (b.ratingCount ?? 0)
            }
        case .priceLow:
            spots.sort { $0.priceTier < $1.priceTier }
        case .priceHigh:
            spots.sort { $0.priceTier > $1.priceTier }
        }

        return spots
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            EmojiScene(["🍽️", "🧀", "🫕", "🍫", "🥐"])
            Text(appState.localized(
                en: "No restaurants found",
                de: "Keine Restaurants gefunden"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if viewModel.activeToggles.contains(.saved) {
                Text(appState.localized(
                    en: "Save restaurants by tapping the heart icon",
                    de: "Speichere Restaurants mit dem Herz-Symbol"
                ))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Surprise Me Button

    private var surpriseMeButton: some View {
        Button(action: pickSurprise) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                Text(appState.localized(en: "Surprise me!", de: "Überrasche mich!"))
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.znNavy)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: Color.znNavy.opacity(0.28), radius: 12, x: 0, y: 6)
        }
    }

    private func pickSurprise() {
        surpriseSpot = viewModel.surpriseMe(savedIDs: appState.savedLunchIDs)
    }
}

// MARK: - Sort Bottom Sheet

struct LunchSortSheet: View {
    @Binding var selectedSort: LunchSort
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(language == .en ? "Sort by" : "Sortieren nach")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.znInk)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.znMuted)
                        .frame(width: 30, height: 30)
                        .background(Color.znBorder.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Sort options
            ForEach(LunchSort.allCases) { sort in
                Button {
                    selectedSort = sort
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: sort.sfSymbol)
                            .font(.system(size: 14))
                            .foregroundStyle(selectedSort == sort ? .znNavy : .znMuted)
                            .frame(width: 20)

                        Text(language == .en ? sort.displayName : sort.displayNameDE)
                            .font(.system(size: 15))
                            .foregroundStyle(selectedSort == sort ? .znInk : .znBody)

                        Spacer()

                        if selectedSort == sort {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.znNavy)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(selectedSort == sort ? Color.znNavy.opacity(0.06) : .clear)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: selectedSort)
            }

            Spacer()
        }
        .background(Color.znSurface)
    }
}

#Preview {
    NavigationStack {
        LunchView()
            .environment(AppState())
            .environment(LocationManager())
            .environment(ToastManager())
    }
}
