import SwiftUI

/// Horizontal scrollable category tabs with item counts.
///
/// Each tab is rendered as a `FilterChip` with the category's localized display name
/// and the number of items in that category.
struct NewsCategoryTab: View {
    @Environment(AppState.self) private var appState

    let categoryKeys: [String]
    @Binding var selectedCategory: String
    let itemCount: (String) -> Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categoryKeys, id: \.self) { key in
                    FilterChip(
                        label: NewsCategories.displayName(for: key, language: appState.language),
                        isSelected: selectedCategory == key,
                        icon: iconName(for: key),
                        count: itemCount(key)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = key
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Category Icons

    private func iconName(for key: String) -> String? {
        switch key {
        case "topStories": return "star.fill"
        case "politics": return "building.columns.fill"
        case "disruptions": return "exclamationmark.triangle.fill"
        case "events": return "calendar"
        case "culture": return "theatermasks.fill"
        case "local": return "mappin"
        default: return nil
        }
    }
}

#Preview {
    NewsCategoryTab(
        categoryKeys: ["topStories", "politics", "disruptions", "events", "culture", "local"],
        selectedCategory: .constant("topStories"),
        itemCount: { _ in 3 }
    )
    .environment(AppState())
}
