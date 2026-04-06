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
                browseTile("Activities", route: .activities) {
                    Image("explore-events").resizable().aspectRatio(contentMode: .fill)
                }
                browseTile("Museums", route: .museums) {
                    Image("explore-museums").resizable().aspectRatio(contentMode: .fill)
                }
                browseTile("Parks & Playgrounds", route: .parks) {
                    Image("explore-parks").resizable().aspectRatio(contentMode: .fill)
                }
                browseTile("Restaurants", route: .restaurants) {
                    Image("explore-restaurants").resizable().aspectRatio(contentMode: .fill)
                }
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

}
