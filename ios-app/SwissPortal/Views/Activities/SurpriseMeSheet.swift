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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        // Venue photo or category icon
                        venueImage
                            .padding(.top, 12)

                        // Activity name
                        Text(activity.localizedName(language: appState.language))
                            .font(.custom("Playfair", size: 22).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Description
                        Text(activity.localizedDescription(language: appState.language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 24)

                        // Badges + price inline
                        VStack(spacing: 6) {
                            badgesRow

                            if let price = activity.localizedPrice(language: appState.language) {
                                HStack(spacing: 6) {
                                    Image(systemName: "banknote")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(price)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Action buttons pinned at bottom
                VStack(spacing: 0) {
                    Divider()
                    actionButtons
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .background(.regularMaterial)
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

    // MARK: - Venue Image / Category Icon

    @ViewBuilder
    private var venueImage: some View {
        if activity.category.lowercased() != "stayhome",
           let photoURL = APIClient.shared.photoURL(for: activity.id) {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                case .failure:
                    categoryEmoji
                default:
                    // Loading placeholder
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.znBorder)
                        .frame(width: 120, height: 120)
                        .overlay {
                            ProgressView()
                        }
                }
            }
        } else {
            categoryEmoji
        }
    }

    private var categoryEmoji: some View {
        ZStack {
            Circle()
                .fill(Color.brand.opacity(0.12))
                .frame(width: 72, height: 72)

            Image(systemName: categoryIcon)
                .font(.system(size: 30))
                .foregroundStyle(.brand)
        }
    }

    private var categoryIcon: String {
        switch activity.category.lowercased() {
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
                color: activity.indoor ? .znNavy : .znTerracotta
            )

            // Duration
            BadgeView(text: activity.duration, icon: "clock", color: .znMuted)

            // Opening hours
            if let hours = activity.localizedOpeningHours(language: appState.language) {
                BadgeView(text: hours, icon: "door.left.hand.open", color: .znMuted)
            }

            // Free badge
            if activity.isFree {
                FreeBadge()
            }

            // Age range
            BadgeView(
                text: activity.ageRange,
                icon: "figure.and.child.holdinghands",
                color: .brand
            )
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary row: Website + Directions + Save
            HStack(spacing: 8) {
                // Website button
                if let urlString = activity.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        actionPill(icon: "safari", label: appState.localized(en: "Website", de: "Webseite"))
                    }
                }

                // Directions button (Apple Maps)
                if activity.lat != nil && activity.lon != nil {
                    Button(action: openInMaps) {
                        actionPill(icon: "arrow.triangle.turn.up.right.diamond", label: appState.localized(en: "Directions", de: "Route"))
                    }
                }

                // Save / heart button
                Button(action: onSave) {
                    actionPill(
                        icon: isSaved ? "heart.fill" : "heart",
                        label: isSaved
                            ? appState.localized(en: "Saved", de: "Gespeichert")
                            : appState.localized(en: "Save", de: "Speichern"),
                        iconColor: isSaved ? .znNegative : .primary
                    )
                }
            }

            // "Try another" button
            Button(action: onTryAnother) {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                    Text(appState.localized(en: "Try another", de: "Nochmal"))
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient.brand)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            }
        }
    }

    private func actionPill(icon: String, label: String, iconColor: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor ?? .primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.znNeutralTagBg)
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }

    private func openInMaps() {
        guard let lat = activity.lat, let lon = activity.lon else { return }
        let urlString = "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=w"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SurpriseMeSheet(
        activity: PreviewData.activity,
        onTryAnother: {},
        onSave: {},
        isSaved: false
    )
    .environment(AppState())
}
