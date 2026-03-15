import SwiftUI

/// Full-width navy gradient hero for the Explore tab.
///
/// Displays "Explore _Zürich_" with the city name in italic Playfair,
/// filter pills inside the hero, and map/grid toggle in top-right.
/// In map mode, collapses to a compact header bar.
struct ExploreHeroBanner: View {
    @Environment(AppState.self) private var appState

    @Binding var filter: ExploreFilter
    let showFullMap: Bool
    let onMapToggle: () -> Void

    var body: some View {
        if showFullMap {
            compactHeader
        } else {
            fullHero
        }
    }

    // MARK: - Full Hero (list mode)

    private var fullHero: some View {
        // Content drives the size; background + decoration layers are overlaid
        VStack(alignment: .leading, spacing: 0) {
            // Title row + icon buttons
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    // Eyebrow
                    Text(eyebrowText)
                        .font(.znEyebrow)
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))

                    // Title: "Explore _the city_"
                    heroTitle
                }

                Spacer()

                HStack(spacing: 8) {
                    GlassButton(systemName: "map", action: onMapToggle)
                    CityMenuButton()
                }
            }

            // Filter pills
            filterPills
                .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy
                    .ignoresSafeArea(.container, edges: .top)

                // Subtle warm glow (top-right)
                RadialGradient(
                    colors: [Color.znTerracotta.opacity(0.22), .clear],
                    center: UnitPoint(x: 1.2, y: -0.3),
                    startRadius: 0,
                    endRadius: 220
                )

                // Skyline silhouette (bottom-right, 9% opacity)
                SkylineIllustration()
                    .frame(width: 200, height: 110)
                    .opacity(0.09)
            }
        }
    }

    // MARK: - Compact Header (map mode)

    private var compactHeader: some View {
        VStack(spacing: 0) {
            // Navy header bar
            HStack {
                // Title
                Text(appState.localized(en: "Explore", de: "Entdecke"))
                    .font(.expandedCardTitle)
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 8) {
                    // List button (back to list)
                    GlassButton(systemName: "list.bullet", size: 32, iconSize: 14, action: onMapToggle)
                    CityMenuButton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Filter pills row
            filterPills
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .background {
            Color.znNavy.opacity(0.9)
                .ignoresSafeArea(.container, edges: .top)
        }
    }

    // MARK: - Eyebrow

    private var eyebrowText: String {
        let formatter = DateFormatter()
        let locale = appState.language == .de ? Locale(identifier: "de_CH") : Locale(identifier: "en_US")
        formatter.locale = locale
        let cityName = appState.city.localizedName(language: appState.language)
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: Date())
        return "\(cityName) · \(dayName)"
    }

    // MARK: - Hero Title

    private var heroTitle: some View {
        (
            Text(appState.localized(en: "Explore ", de: "Entdecke "))
                .font(.bannerTitle)
                .foregroundStyle(.white)
            + Text(appState.localized(en: "the city", de: "die Stadt"))
                .font(.custom("Playfair", size: 28).italic())
                .foregroundStyle(.white.opacity(0.65))
        )
        .lineLimit(1)
    }

    // (Skyline, glass buttons, and city menu use shared components)

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExploreFilter.allCases, id: \.self) { f in
                    let isSelected = filter == f
                    Button {
                        withAnimation(AppAnimation.spring) {
                            filter = f
                        }
                    } label: {
                        Label(
                            appState.language == .en ? f.displayName : f.displayNameDE,
                            systemImage: f.sfSymbol
                        )
                        .font(.caption.weight(.medium))
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
    }
}

// MARK: - City Menu

private struct ExploreCityMenu: View {
    @Environment(AppState.self) private var appState

    var body: some View {
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
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

#Preview("List Mode") {
    ExploreHeroBanner(
        filter: .constant(.all),
        showFullMap: false,
        onMapToggle: {}
    )
    .padding()
    .environment(AppState())
}

#Preview("Map Mode") {
    ExploreHeroBanner(
        filter: .constant(.all),
        showFullMap: true,
        onMapToggle: {}
    )
    .environment(AppState())
}
