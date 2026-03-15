import SwiftUI

/// Accordion-style news card with expanding detail panel.
///
/// Collapsed: Left accent bar, Playfair headline, 2-line summary, metadata row.
/// Expanded: Photo panel, unclamped summary, meta grid, action buttons.
/// Only one card expands at a time via the shared `expandedID` binding.
struct NewsCard: View {
    @Environment(AppState.self) private var appState

    let item: NewsItem
    var category: String = "topStories"
    @Binding var expandedID: String?

    private var isExpanded: Bool { expandedID == item.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 6) {
                sourceRow
                headline
                    .padding(.bottom, 1)
                summaryText
                footerRow

                if isExpanded {
                    expandedContent
                }
            }
            .padding(AppSpacing.cardPadding)
            .padding(.leading, isExpanded ? 0 : 4)
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.newsCardRadius))
        .overlay(alignment: .leading) {
            // Left accent bar — fades on expand
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.categoryColor(category))
                .frame(width: AppSpacing.borderStripWidth)
                .padding(.vertical, 8)
                .opacity(isExpanded ? 0 : 1)
        }
        .shadow(
            color: isExpanded ? AppShadow.cardExpanded.color : AppShadow.card.color,
            radius: isExpanded ? AppShadow.cardExpanded.radius : AppShadow.card.radius,
            x: 0,
            y: isExpanded ? AppShadow.cardExpanded.y : AppShadow.card.y
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AppAnimation.spring) {
                if isExpanded {
                    expandedID = nil
                } else {
                    expandedID = item.id
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
    }

    // MARK: - Headline

    private var headline: some View {
        Text(item.localizedHeadline(language: appState.language))
            .font(.newsCardHeadline)
            .foregroundStyle(.znInk)
            .lineLimit(isExpanded ? nil : 3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Summary

    private var summaryText: some View {
        Text(item.localizedSummary(language: appState.language))
            .font(.caption)
            .foregroundStyle(.znBody)
            .lineLimit(isExpanded ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Source Row

    private var sourceRow: some View {
        HStack(spacing: 7) {
            Text(item.source)
                .font(.znEyebrow)
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(.znMuted)

            Circle()
                .fill(Color.znBorder)
                .frame(width: 2, height: 2)

            if let timeAgo = item.timeAgo {
                Text(timeAgo)
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(.znMuted)
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            SentimentBadge(sentiment: item.sentiment)
            Spacer()
            if !isExpanded {
                HStack(spacing: 3) {
                    Text(appState.localized(en: "Expand", de: "Mehr"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.znNavy)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.znChevron)
                }
            }
        }
        .padding(.top, 9)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .foregroundStyle(.znInnerDivider)

            // Detail text if available
            if let detail = item.localizedDetail(language: appState.language), !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.znBody)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Meta detail grid
            metaGrid

            // Action buttons
            HStack(spacing: 12) {
                if let urlString = item.url, let url = URL(string: urlString) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label(appState.localized(en: "Read more", de: "Weiterlesen"), systemImage: "arrow.up.right")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.znNavy)
                            .clipShape(Capsule())
                    }
                }

                Button {
                    shareArticle()
                } label: {
                    Label(appState.localized(en: "Share", de: "Teilen"), systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.znNavy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.znNavy.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Meta Grid

    private var metaGrid: some View {
        let gridItems = [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: gridItems, alignment: .leading, spacing: 6) {
            metaGridCell(icon: "newspaper", label: appState.localized(en: "Source", de: "Quelle"), value: item.source)
            if let timeAgo = item.timeAgo {
                metaGridCell(icon: "clock", label: appState.localized(en: "Published", de: "Veröffentlicht"), value: timeAgo)
            }
            metaGridCell(icon: "tag", label: appState.localized(en: "Category", de: "Kategorie"), value: NewsCategories.displayName(for: category, language: appState.language))
            if let sentiment = item.sentiment, sentiment != "neutral" {
                metaGridCell(icon: "arrow.up.arrow.down", label: appState.localized(en: "Sentiment", de: "Stimmung"), value: sentiment.capitalized)
            }
        }
    }

    private func metaGridCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.znMuted)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.znMuted)
                    .textCase(.uppercase)
                Text(value)
                    .font(.caption2)
                    .foregroundStyle(.znBody)
            }
        }
    }

    // MARK: - Helpers

    private func shareArticle() {
        let text = item.localizedHeadline(language: appState.language)
        var shareItems: [Any] = [text]
        if let urlString = item.url, let url = URL(string: urlString) {
            shareItems.append(url)
        }
        let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
}

#Preview {
    let sampleItem = NewsItem(
        headline: "Swiss National Bank Holds Rates Steady",
        headlineDE: "Schweizerische Nationalbank hält Zinsen stabil",
        summary: "The SNB decided to keep interest rates unchanged amid global uncertainty.",
        summaryDE: "Die SNB hat entschieden, die Zinsen angesichts globaler Unsicherheit unverändert zu lassen.",
        detail: "The Swiss National Bank maintained its policy rate at 1.75%, citing stable inflation expectations and a resilient domestic economy. The decision was widely expected by analysts.",
        detailDE: nil,
        source: "NZZ",
        url: "https://www.nzz.ch",
        sentiment: "neutral",
        publishedAt: "2026-02-21T10:30:00Z"
    )

    NewsCard(item: sampleItem, expandedID: .constant(nil))
        .padding()
        .environment(AppState())
}
