import SwiftUI

/// Daily briefing card shown at the top of the News view.
///
/// Displays a time-based greeting, today's top story headline + summary,
/// and an optional suggested activity. Dismissible per day via UserDefaults.
struct BriefingCard: View {
    @Environment(AppState.self) private var appState

    let briefing: Briefing
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: greeting + dismiss button
            HStack {
                Text(greeting)
                    .font(.cardHeadline)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.znBorder)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Top story
            if let topStory = briefing.topStory {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topStory.headline)
                        .font(.cardTitle)
                        .lineLimit(2)

                    Text(topStory.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    HStack(spacing: 4) {
                        Text(topStory.source)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let url = URL(string: topStory.url) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            // Suggested Activity
            if let activity = briefing.suggestedActivity {
                Divider()

                Button {
                    appState.selectedTab = .discover
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: activity.indoor ? "house.fill" : "leaf.fill")
                            .font(.title3)
                            .foregroundStyle(.znTerracotta)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(appState.localized(
                                en: "Today's Pick",
                                de: "Tipp des Tages"
                            ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                            Text(activity.localizedName(language: appState.language))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text(activity.localizedDescription(language: appState.language))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.brand.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.brand.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return appState.localized(en: "Good morning", de: "Guten Morgen")
        } else if hour < 17 {
            return appState.localized(en: "Good afternoon", de: "Guten Nachmittag")
        } else {
            return appState.localized(en: "Good evening", de: "Guten Abend")
        }
    }

}
