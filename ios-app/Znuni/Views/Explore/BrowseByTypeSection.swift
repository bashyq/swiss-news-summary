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
                    .font(.compactCardTitle)
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
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, x: AppShadow.card.x, y: AppShadow.card.y)
    }

    // MARK: - Wide Card

    private var wideCard: some View {
        ZStack {
            // Photo background
            Image("explore-deals")
                .resizable()
                .aspectRatio(contentMode: .fill)

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
                    .font(.compactCardTitle)
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
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
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

    // MARK: - Photo Backgrounds

    private func categoryImageName(for category: ExploreCategory) -> String {
        switch category {
        case .museums: return "explore-museums"
        case .parks: return "explore-parks"
        case .restaurants: return "explore-restaurants"
        case .events: return "explore-events"
        case .deals: return "explore-deals"
        }
    }

    private func illustrationBackground(for category: ExploreCategory) -> some View {
        Image(categoryImageName(for: category))
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

#Preview {
    NavigationStack {
        BrowseByTypeSection(countForCategory: { _ in 12 })
    }
    .environment(AppState())
}
