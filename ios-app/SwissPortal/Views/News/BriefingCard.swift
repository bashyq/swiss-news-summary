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
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.bold)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Top story
            if let topStory = briefing.topStory {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topStory.headline)
                        .font(.system(.subheadline, design: .serif))
                        .fontWeight(.semibold)
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

            // Daily Pick
            if let pick = briefing.dailyPick {
                Divider()

                Button {
                    appState.selectedTab = .activities
                } label: {
                    HStack(spacing: 10) {
                        Text(pick.emoji)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(appState.localized(
                                en: "Today's Pick",
                                de: "Tipp des Tages"
                            ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                            Text(pick.localizedName(language: appState.language))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text(pick.localizedReason(language: appState.language))
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
        .padding(14)
        .background(Color.brand.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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
