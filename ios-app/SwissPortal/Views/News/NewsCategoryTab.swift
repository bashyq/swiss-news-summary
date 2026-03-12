import SwiftUI

/// Horizontal scroll of category pill chips with item counts.
///
/// Shows a "Top stories" section header, then a horizontally scrolling
/// row of pill chips — each with category name, icon, and count.
struct NewsCategoryTab: View {
    @Environment(AppState.self) private var appState

    let categoryKeys: [String]
    @Binding var selectedCategory: String
    let itemCount: (String) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header — "Local News" + story count
            HStack(alignment: .firstTextBaseline) {
                Text(appState.localized(en: "Local News", de: "Lokale News"))
                    .font(.sectionHeadline)
                    .foregroundStyle(.znInk)
                Spacer()
                Text(appState.localized(
                    en: "\(totalCount) stories today",
                    de: "\(totalCount) Meldungen heute"
                ))
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(.znMuted)
            }
            .padding(.horizontal)

            // Horizontal pill scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(categoryKeys, id: \.self) { key in
                        let isSelected = selectedCategory == key
                        let count = itemCount(key)
                        Button {
                            withAnimation(AppAnimation.standardEase) {
                                selectedCategory = key
                            }
                        } label: {
                            HStack(spacing: 5) {
                                if let icon = iconName(for: key), isSelected {
                                    Image(systemName: icon)
                                        .font(.system(size: 9))
                                }
                                Text(NewsCategories.displayName(for: key, language: appState.language))
                                    .font(.system(size: 12, weight: .medium))
                                // Count circle
                                Text("\(count)")
                                    .font(.system(size: 10))
                                    .frame(width: 16, height: 16)
                                    .background(
                                        isSelected
                                            ? Color.white.opacity(0.18)
                                            : Color.znBorder
                                    )
                                    .foregroundStyle(
                                        isSelected ? .white : .znMuted
                                    )
                                    .clipShape(Circle())
                            }
                            .padding(.horizontal, 13)
                            .frame(height: 31)
                            .background(isSelected ? Color.znNavy : .clear)
                            .foregroundStyle(isSelected ? .white : .znBody)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? .clear : Color.znBorder, lineWidth: 1.5)
                            )
                        }
                        .sensoryFeedback(.selection, trigger: isSelected)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var totalCount: Int {
        categoryKeys.reduce(0) { $0 + itemCount($1) }
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
