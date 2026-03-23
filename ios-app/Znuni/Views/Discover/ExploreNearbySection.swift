import SwiftUI

struct ExploreNearbySection: View {
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore nearby")
                .font(.sectionHeadline)
                .foregroundStyle(Color.znInk)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                browseTile("Activities", route: .activities) { playgroundIllustration }
                browseTile("Museums", route: .museums) { museumIllustration }
                browseTile("Parks & Playgrounds", route: .parks) { parkIllustration }
                browseTile("Restaurants", route: .restaurants) { restaurantIllustration }
            }

            Button { path.append(DiscoverRoute.map) } label: {
                Label("View map", systemImage: "map")
                    .font(.znLabel)
                    .foregroundStyle(Color.znNavy)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.znSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.znBorder, lineWidth: 1))
            }
        }
    }

    private func browseTile<I: View>(_ title: String, route: DiscoverRoute, @ViewBuilder illustration: @escaping () -> I) -> some View {
        Button {
            ZnuniEvent.discoverCategoryTapped(category: title.lowercased())
            path.append(route)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Canvas illustration area
                illustration()
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: AppSpacing.cardRadius,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: AppSpacing.cardRadius
                        )
                    )

                // Title below illustration
                Text(title)
                    .font(.cardHeadline)
                    .foregroundStyle(Color.znInk)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, 10)
            }
            .background(Color.znSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(Color.znBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Illustrations (migrated from BrowseByTypeSection)

    /// Museum — columns, pediment, warm stone tones
    private var museumIllustration: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.66, green: 0.70, blue: 0.78)
            LinearGradient(
                colors: [Color(red: 0.60, green: 0.68, blue: 0.75), Color(red: 0.66, green: 0.70, blue: 0.78)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 0) {
                NearbyTriangle()
                    .fill(Color(red: 0.78, green: 0.74, blue: 0.66))
                    .frame(width: 90, height: 15)
                Rectangle()
                    .fill(Color(red: 0.83, green: 0.79, blue: 0.72))
                    .frame(width: 90, height: 50)
                    .overlay(
                        HStack(spacing: 10) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color(red: 0.88, green: 0.85, blue: 0.78))
                                    .frame(width: 5, height: 34)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.54, green: 0.48, blue: 0.37))
                            .frame(width: 22, height: 34)
                            .offset(y: 8),
                        alignment: .bottom
                    )
            }
        }
    }

    /// Park — sky, trees, grass
    private var parkIllustration: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.66, green: 0.77, blue: 0.85), Color(red: 0.78, green: 0.87, blue: 0.75)],
                startPoint: .top, endPoint: .bottom
            )
            Rectangle()
                .fill(Color(red: 0.55, green: 0.69, blue: 0.45))
                .frame(height: 30)
            HStack(spacing: 18) {
                nearbyTree(scale: 0.8)
                nearbyTree(scale: 0.55)
                nearbyTree(scale: 1.0)
            }
            .offset(y: -22)
            Ellipse()
                .fill(Color.white.opacity(0.35))
                .frame(width: 36, height: 13)
                .offset(x: -22, y: -60)
        }
    }

    /// Restaurant — warm facade with awning
    private var restaurantIllustration: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.83, green: 0.72, blue: 0.59)
            Rectangle()
                .fill(Color(red: 0.72, green: 0.56, blue: 0.41))
                .frame(height: 22)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.znTerracotta.opacity(0.65))
                    .frame(width: 80, height: 10)
                Rectangle()
                    .fill(Color(red: 0.91, green: 0.83, blue: 0.72))
                    .frame(width: 80, height: 38)
                    .overlay(
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.56, green: 0.72, blue: 0.82).opacity(0.65))
                                .frame(width: 16, height: 20)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.56, green: 0.72, blue: 0.82).opacity(0.65))
                                .frame(width: 16, height: 20)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.54, green: 0.42, blue: 0.25))
                            .frame(width: 18, height: 26)
                            .offset(y: 6),
                        alignment: .bottom
                    )
            }
            .offset(y: -22)
        }
    }

    /// Playground — slide, swings, grass
    private var playgroundIllustration: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.66, green: 0.77, blue: 0.85), Color(red: 0.78, green: 0.87, blue: 0.72)],
                startPoint: .top, endPoint: .bottom
            )
            Rectangle()
                .fill(Color(red: 0.56, green: 0.75, blue: 0.42))
                .frame(height: 28)
            HStack(spacing: 22) {
                // Slide
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.znTerracotta.opacity(0.8))
                        .frame(width: 5, height: 30)
                    Rectangle()
                        .fill(Color.znTerracotta)
                        .frame(width: 22, height: 3)
                        .rotationEffect(.degrees(-35))
                        .offset(x: 8)
                }
                // Swing
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(red: 0.54, green: 0.42, blue: 0.19))
                        .frame(width: 30, height: 3)
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color(red: 0.42, green: 0.31, blue: 0.19))
                            .frame(width: 2, height: 20)
                        Rectangle()
                            .fill(Color(red: 0.42, green: 0.31, blue: 0.19))
                            .frame(width: 2, height: 20)
                    }
                }
            }
            .offset(y: -24)
        }
    }

    private func nearbyTree(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Ellipse()
                .fill(Color(red: 0.36, green: 0.54, blue: 0.23))
                .frame(width: 20 * scale, height: 24 * scale)
            Rectangle()
                .fill(Color(red: 0.29, green: 0.44, blue: 0.19))
                .frame(width: 4 * scale, height: 11 * scale)
        }
    }
}

// MARK: - Triangle Shape

private struct NearbyTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
