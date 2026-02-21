import SwiftUI

/// Sheet displaying a randomly picked activity with a fun, playful presentation.
///
/// Shows a large category icon, the activity name, description, badges,
/// and action buttons for trying another random pick, opening the URL, or saving.
struct SurpriseMeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let activity: Activity
    let onTryAnother: () -> Void
    let onSave: () -> Void
    let isSaved: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Large category icon
                    categoryEmoji
                        .padding(.top, 24)

                    // Activity name
                    Text(activity.localizedName(language: appState.language))
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Description
                    Text(activity.localizedDescription(language: appState.language))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Badges
                    badgesRow

                    // Price info
                    if let price = activity.localizedPrice(language: appState.language) {
                        HStack(spacing: 6) {
                            Image(systemName: "banknote")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(price)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                        .padding(.horizontal, 32)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal, 24)

                    Spacer(minLength: 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Category Emoji / Icon

    private var categoryEmoji: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 96, height: 96)

            Image(systemName: categoryIcon)
                .font(.system(size: 40))
                .foregroundStyle(.purple)
        }
    }

    private var categoryIcon: String {
        switch activity.category?.lowercased() {
        case "animals": return "pawprint.fill"
        case "playground": return "figure.play"
        case "museum": return "building.columns.fill"
        case "nature": return "leaf.fill"
        case "water": return "drop.fill"
        case "transport": return "tram.fill"
        case "creative": return "paintpalette.fill"
        case "music": return "music.note"
        case "sports": return "sportscourt.fill"
        case "food": return "fork.knife"
        default: return "sparkles"
        }
    }

    // MARK: - Badges Row

    private var badgesRow: some View {
        HStack(spacing: 8) {
            // Indoor/Outdoor
            BadgeView(
                text: activity.indoor
                    ? appState.localized(en: "Indoor", de: "Indoor")
                    : appState.localized(en: "Outdoor", de: "Outdoor"),
                icon: activity.indoor ? "house.fill" : "sun.max.fill",
                color: activity.indoor ? .blue : .orange
            )

            // Duration
            if let duration = activity.duration {
                BadgeView(text: duration, icon: "clock", color: .gray)
            }

            // Free badge
            if activity.isFree {
                FreeBadge()
            }

            // Age range
            if let ageRange = activity.ageRange {
                BadgeView(
                    text: ageRange,
                    icon: "figure.and.child.holdinghands",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // "Try another" button
            Button(action: onTryAnother) {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                    Text(appState.localized(en: "Try another", de: "Nochmal"))
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 12) {
                // "Open" button (opens URL)
                if let urlString = activity.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                            Text(appState.localized(en: "Open", de: "Offnen"))
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Save / heart button
                Button(action: onSave) {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .foregroundStyle(isSaved ? .red : .primary)
                        Text(isSaved
                             ? appState.localized(en: "Saved", de: "Gespeichert")
                             : appState.localized(en: "Save", de: "Speichern")
                        )
                        .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

#Preview {
    let sample = Activity(
        id: "zoo-zurich",
        name: "Zoo Zurich",
        nameDE: "Zoo Zurich",
        description: "One of the best zoos in Europe with a large Masoala Rainforest hall.",
        descriptionDE: "Einer der besten Zoos Europas mit einer grossen Masoala-Regenwaldhalle.",
        indoor: false,
        ageRange: "2-5 years",
        duration: "2-4 hours",
        price: "CHF 29 adults, kids under 6 free",
        priceDE: nil,
        url: "https://www.zoo.ch",
        lat: 47.3849,
        lon: 8.5743,
        category: "animals",
        minAge: 2,
        maxAge: 5,
        season: nil,
        free: false,
        recurring: nil,
        stayHome: nil,
        subcategory: nil,
        materials: nil,
        materialsDE: nil
    )

    SurpriseMeSheet(
        activity: sample,
        onTryAnother: {},
        onSave: {},
        isSaved: false
    )
    .environment(AppState())
}
