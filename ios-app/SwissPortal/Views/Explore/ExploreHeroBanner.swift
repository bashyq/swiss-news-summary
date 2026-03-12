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
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.42))

                    // Title: "Explore _the city_"
                    heroTitle
                }

                Spacer()

                HStack(spacing: 8) {
                    glassButton(systemName: "map", action: onMapToggle)
                    cityMenuButton
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
                skylineIllustration
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
                    .font(.custom("Playfair", size: 18).weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                HStack(spacing: 8) {
                    // List button (back to list)
                    glassButton(systemName: "list.bullet", size: 32, iconSize: 14, radius: 8, action: onMapToggle)
                    cityMenuButton
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
                .font(.custom("Playfair", size: 28))
                .foregroundStyle(.white)
            + Text(appState.localized(en: "the city", de: "die Stadt"))
                .font(.custom("Playfair", size: 28).italic())
                .foregroundStyle(.white.opacity(0.65))
        )
        .lineLimit(1)
    }

    // MARK: - Skyline Illustration

    /// City skyline silhouette — buildings, church spires, rooftops (matches mockup SVG)
    private var skylineIllustration: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let white = Color.white
            // Building 1: tower with spire
            ctx.fill(Path(CGRect(x: w * 0.05, y: h * 0.36, width: w * 0.09, height: h * 0.64)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.05, y: h * 0.36))
                p.addLine(to: CGPoint(x: w * 0.095, y: h * 0.11))
                p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.36))
                p.closeSubpath()
            }, with: .color(white))
            // Building 2: wider with triangular roof
            ctx.fill(Path(CGRect(x: w * 0.19, y: h * 0.45, width: w * 0.11, height: h * 0.55)), with: .color(white))
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.19, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.245, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.45))
                p.closeSubpath()
            }, with: .color(white))
            // Building 3: dome building
            ctx.fill(Path(CGRect(x: w * 0.36, y: h * 0.41, width: w * 0.08, height: h * 0.59)), with: .color(white))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.32, y: h * 0.29, width: w * 0.16, height: h * 0.18)), with: .color(white))
            // Building 4: tall rectangular
            ctx.fill(Path(CGRect(x: w * 0.50, y: h * 0.32, width: w * 0.14, height: h * 0.68)), with: .color(white))
            // Building 5: mountain/church spire
            ctx.fill(Path { p in
                p.move(to: CGPoint(x: w * 0.69, y: h))
                p.addLine(to: CGPoint(x: w * 0.79, y: h * 0.25))
                p.addLine(to: CGPoint(x: w * 0.89, y: h))
                p.closeSubpath()
            }, with: .color(white))
            // Horizon bar
            ctx.fill(Path(CGRect(x: 0, y: h * 0.76, width: w, height: h * 0.13)), with: .color(white.opacity(0.25)))
        }
    }

    // MARK: - Glass Buttons

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

    // MARK: - City Menu Button

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
