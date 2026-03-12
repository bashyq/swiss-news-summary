import SwiftUI

/// "Browse by type" 2×2 category grid with a wide featured card.
///
/// Each card has an illustrated background, wash overlay, frosted icon badge,
/// and bottom-aligned label/title/count — matching the Znüni mockup.
struct BrowseByTypeSection: View {
    @Environment(AppState.self) private var appState

    let countForCategory: (ExploreCategory) -> Int
    /// Called when the Restaurants tile is tapped — switches to Lunch tab.
    var onRestaurantsTap: (() -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let gridCategories: [ExploreCategory] = [.museums, .parks, .restaurants, .events]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text(appState.localized(en: "Browse by type", de: "Nach Typ durchsuchen"))
                .font(.sectionHeadline)
                .foregroundStyle(.znInk)
                .padding(.horizontal, 20)
                .padding(.top, 22)

            // 2×2 grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(gridCategories) { category in
                    if category == .restaurants, let onRestaurantsTap {
                        Button {
                            onRestaurantsTap()
                        } label: {
                            categoryCard(category)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: category) {
                            categoryCard(category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Wide featured card
            NavigationLink(value: ExploreCategory.deals) {
                wideCard
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Category Card

    private func categoryCard(_ category: ExploreCategory) -> some View {
        ZStack {
            // Illustrated background
            illustrationBackground(for: category)

            // Wash overlay — gradient for text legibility
            LinearGradient(
                colors: [
                    Color.znSurface.opacity(0.72),
                    Color.znNavy.opacity(0.55)
                ],
                startPoint: .init(x: 0.3, y: 0),
                endPoint: .init(x: 0.7, y: 1)
            )

            // Frosted icon badge — top right
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: category.sfSymbol)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.22))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(12)

            // Content — bottom left
            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text(categoryLabel(category))
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
                Text(appState.language == .en ? category.displayName : category.displayNameDE)
                    .font(.custom("Playfair", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                let count = countForCategory(category)
                if count > 0 {
                    Text(countLabel(category, count: count))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .aspectRatio(1 / 0.82, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }

    // MARK: - Wide Card

    private var wideCard: some View {
        ZStack {
            // Lake illustration
            lakeIllustration

            // Wash
            LinearGradient(
                colors: [
                    Color.znSurface.opacity(0.75),
                    Color.znNavy.opacity(0.45)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Icon badge — top right
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "water.waves")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.22))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(12)

            // Content — bottom left
            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text(appState.localized(en: "Featured", de: "Empfohlen"))
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
                Text(appState.localized(en: "Deals & Free", de: "Angebote & Gratis"))
                    .font(.custom("Playfair", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                let count = countForCategory(.deals)
                if count > 0 {
                    Text(appState.localized(en: "\(count) available", de: "\(count) verfügbar"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }

    // MARK: - Labels

    private func categoryLabel(_ category: ExploreCategory) -> String {
        switch category {
        case .museums: return appState.localized(en: "Culture", de: "Kultur")
        case .parks: return appState.localized(en: "Outdoors", de: "Draussen")
        case .restaurants: return appState.localized(en: "Food & drink", de: "Essen & Trinken")
        case .events: return appState.localized(en: "Family", de: "Familie")
        case .deals: return appState.localized(en: "Featured", de: "Empfohlen")
        }
    }

    private func countLabel(_ category: ExploreCategory, count: Int) -> String {
        switch category {
        case .museums: return appState.localized(en: "\(count) venues", de: "\(count) Orte")
        case .parks: return appState.localized(en: "\(count) green spaces", de: "\(count) Grünflächen")
        case .restaurants: return appState.localized(en: "\(count)+ places", de: "\(count)+ Lokale")
        case .events: return appState.localized(en: "\(count) events", de: "\(count) Events")
        case .deals: return appState.localized(en: "\(count) available", de: "\(count) verfügbar")
        }
    }

    // MARK: - Illustrated Backgrounds

    @ViewBuilder
    private func illustrationBackground(for category: ExploreCategory) -> some View {
        switch category {
        case .museums: museumIllustration
        case .parks: parkIllustration
        case .restaurants: restaurantIllustration
        case .events: playgroundIllustration
        case .deals: lakeIllustration
        }
    }

    /// Museum — columns, pediment, warm stone tones
    private var museumIllustration: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.66, green: 0.70, blue: 0.78)
            // Sky gradient
            LinearGradient(
                colors: [Color(red: 0.60, green: 0.68, blue: 0.75), Color(red: 0.66, green: 0.70, blue: 0.78)],
                startPoint: .top, endPoint: .bottom
            )
            // Building facade
            VStack(spacing: 0) {
                // Pediment triangle
                BrowseTriangle()
                    .fill(Color(red: 0.78, green: 0.74, blue: 0.66))
                    .frame(width: 120, height: 20)
                // Main block
                Rectangle()
                    .fill(Color(red: 0.83, green: 0.79, blue: 0.72))
                    .frame(width: 120, height: 70)
                    .overlay(
                        HStack(spacing: 12) {
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color(red: 0.88, green: 0.85, blue: 0.78))
                                    .frame(width: 6, height: 45)
                            }
                        }
                    )
                    .overlay(
                        // Door
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.54, green: 0.48, blue: 0.37))
                            .frame(width: 28, height: 44)
                            .offset(y: 13),
                        alignment: .bottom
                    )
            }
        }
    }

    /// Park — sky, trees, grass
    private var parkIllustration: some View {
        ZStack(alignment: .bottom) {
            // Sky
            LinearGradient(
                colors: [Color(red: 0.66, green: 0.77, blue: 0.85), Color(red: 0.78, green: 0.87, blue: 0.75)],
                startPoint: .top, endPoint: .bottom
            )
            // Grass
            Rectangle()
                .fill(Color(red: 0.55, green: 0.69, blue: 0.45))
                .frame(height: 50)
            // Trees
            HStack(spacing: 24) {
                browseTree(scale: 1.0)
                browseTree(scale: 0.7)
                browseTree(scale: 1.2)
            }
            .offset(y: -38)
            // Cloud
            Ellipse()
                .fill(Color.white.opacity(0.35))
                .frame(width: 50, height: 18)
                .offset(x: -30, y: -90)
        }
    }

    /// Restaurant — warm facade with awning
    private var restaurantIllustration: some View {
        ZStack(alignment: .bottom) {
            // Sky
            Color(red: 0.83, green: 0.72, blue: 0.59)
            // Ground
            Rectangle()
                .fill(Color(red: 0.72, green: 0.56, blue: 0.41))
                .frame(height: 35)
            // Building
            VStack(spacing: 0) {
                // Awning
                Rectangle()
                    .fill(Color.znTerracotta.opacity(0.65))
                    .frame(width: 110, height: 14)
                // Facade
                Rectangle()
                    .fill(Color(red: 0.91, green: 0.83, blue: 0.72))
                    .frame(width: 110, height: 50)
                    .overlay(
                        HStack(spacing: 18) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.56, green: 0.72, blue: 0.82).opacity(0.65))
                                .frame(width: 20, height: 26)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.56, green: 0.72, blue: 0.82).opacity(0.65))
                                .frame(width: 20, height: 26)
                        }
                    )
                    .overlay(
                        // Door
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.54, green: 0.42, blue: 0.25))
                            .frame(width: 24, height: 34)
                            .offset(y: 8),
                        alignment: .bottom
                    )
            }
            .offset(y: -35)
        }
    }

    /// Playground — slide, swings, grass
    private var playgroundIllustration: some View {
        ZStack(alignment: .bottom) {
            // Sky
            LinearGradient(
                colors: [Color(red: 0.66, green: 0.77, blue: 0.85), Color(red: 0.78, green: 0.87, blue: 0.72)],
                startPoint: .top, endPoint: .bottom
            )
            // Grass
            Rectangle()
                .fill(Color(red: 0.56, green: 0.75, blue: 0.42))
                .frame(height: 45)
            // Slide structure
            HStack(spacing: 30) {
                // Slide
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.znTerracotta.opacity(0.8))
                        .frame(width: 6, height: 40)
                    Rectangle()
                        .fill(Color.znTerracotta)
                        .frame(width: 30, height: 4)
                        .rotationEffect(.degrees(-35))
                        .offset(x: 10)
                }
                // Swing
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(red: 0.54, green: 0.42, blue: 0.19))
                        .frame(width: 40, height: 4)
                    HStack(spacing: 16) {
                        Rectangle()
                            .fill(Color(red: 0.42, green: 0.31, blue: 0.19))
                            .frame(width: 2, height: 28)
                        Rectangle()
                            .fill(Color(red: 0.42, green: 0.31, blue: 0.19))
                            .frame(width: 2, height: 28)
                    }
                }
            }
            .offset(y: -40)
        }
    }

    /// Lake — water, mountains, sky
    private var lakeIllustration: some View {
        ZStack(alignment: .bottom) {
            // Sky
            LinearGradient(
                colors: [Color(red: 0.53, green: 0.72, blue: 0.85), Color(red: 0.66, green: 0.78, blue: 0.91)],
                startPoint: .top, endPoint: .bottom
            )
            // Water
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.48, green: 0.68, blue: 0.78), Color(red: 0.41, green: 0.60, blue: 0.72)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: 45)
            // Mountains
            BrowseTriangle()
                .fill(Color(red: 0.56, green: 0.66, blue: 0.72).opacity(0.55))
                .frame(width: 140, height: 50)
                .offset(x: -30, y: -38)
            BrowseTriangle()
                .fill(Color(red: 0.50, green: 0.60, blue: 0.68).opacity(0.45))
                .frame(width: 100, height: 35)
                .offset(x: 40, y: -38)
        }
    }

    private func browseTree(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Ellipse()
                .fill(Color(red: 0.36, green: 0.54, blue: 0.23))
                .frame(width: 24 * scale, height: 28 * scale)
            Rectangle()
                .fill(Color(red: 0.29, green: 0.44, blue: 0.19))
                .frame(width: 5 * scale, height: 14 * scale)
        }
    }
}

// MARK: - Triangle Shape

private struct BrowseTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

#Preview {
    NavigationStack {
        BrowseByTypeSection(countForCategory: { _ in 12 })
    }
    .environment(AppState())
}
