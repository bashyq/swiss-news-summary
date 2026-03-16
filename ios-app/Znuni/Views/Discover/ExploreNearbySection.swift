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
                browseTile("Activities", icon: "star.fill", route: .activities)
                browseTile("Museums", icon: "building.columns.fill", route: .museums)
                browseTile("Parks", icon: "leaf.fill", route: .parks)
                browseTile("Restaurants", icon: "fork.knife", route: .restaurants)
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

    private func browseTile(_ title: String, icon: String, route: DiscoverRoute) -> some View {
        Button { path.append(route) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.znNavy)
                Text(title)
                    .font(.cardHeadline)
                    .foregroundStyle(Color.znInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .background(Color.znSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(Color.znBorder, lineWidth: 1)
            )
        }
    }
}
