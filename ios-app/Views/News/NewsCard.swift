import SwiftUI

/// A card view for a single news article.
///
/// Displays the headline, summary, source badge, time ago, and sentiment.
/// Tapping opens the article URL in Safari. An optional detail section
/// is available via a disclosure group.
struct NewsCard: View {
    @Environment(AppState.self) private var appState

    let item: NewsItem

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Headline
            headline

            // Summary
            summary

            // Metadata row: source, time ago, sentiment
            metadataRow

            // Expandable detail section
            if let detail = item.localizedDetail(language: appState.language),
               !detail.isEmpty {
                detailSection(detail)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            openURL()
        }
    }

    // MARK: - Headline

    private var headline: some View {
        Text(item.localizedHeadline(language: appState.language))
            .font(.subheadline)
            .fontWeight(.semibold)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Summary

    private var summary: some View {
        Text(item.localizedSummary(language: appState.language))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(isExpanded ? nil : 3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 6) {
            // Source badge
            BadgeView(
                text: item.source,
                icon: "newspaper",
                color: .blue,
                style: .filled
            )

            // Time ago
            if let timeAgo = item.timeAgo {
                Text(timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Sentiment badge
            SentimentBadge(sentiment: item.sentiment)

            // External link indicator
            if item.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Detail Section

    private func detailSection(_ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.vertical, 4)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(appState.localized(en: "More details", de: "Mehr Details"))
                        .font(.caption2)
                        .fontWeight(.medium)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Open URL

    private func openURL() {
        guard let urlString = item.url,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
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

    NewsCard(item: sampleItem)
        .padding()
        .environment(AppState())
}
