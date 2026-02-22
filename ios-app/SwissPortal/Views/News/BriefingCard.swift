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

            // Suggested activity
            if let activity = briefing.suggestedActivity, let name = activity.name {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: categoryIcon(for: activity.category))
                        .font(.caption)
                        .foregroundStyle(.brand)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(appState.localized(
                            en: "Suggested activity",
                            de: "Vorgeschlagene Aktivität"
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                        Text(appState.language == .de ? (activity.nameDE ?? name) : name)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    if let urlString = activity.url, let url = URL(string: urlString) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.brand)
                        }
                        .buttonStyle(.plain)
                    }
                }
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

    private func categoryIcon(for category: String?) -> String {
        switch category?.lowercased() {
        case "animals": return "pawprint.fill"
        case "playground": return "figure.play"
        case "museum": return "building.columns.fill"
        case "nature": return "leaf.fill"
        case "water": return "drop.fill"
        case "creative": return "paintpalette.fill"
        default: return "star.fill"
        }
    }
}
