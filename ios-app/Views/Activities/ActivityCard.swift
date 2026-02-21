import SwiftUI
import CoreLocation

/// Card view for a single activity.
///
/// Displays the activity name, description, badges (indoor/outdoor, duration, price, age),
/// a save/heart button, and optional distance from the user's location.
/// Tapping the card opens the activity URL if available.
struct ActivityCard: View {
    @Environment(AppState.self) private var appState

    let activity: Activity
    let language: AppLanguage
    let location: CLLocation?

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
            // Header: name + category icon + heart button
            headerRow

            // Description (2 lines max)
            Text(activity.localizedDescription(language: language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Badges row
            badgesRow

            // Distance badge (if location available)
            if let distanceText = distanceBadgeText {
                DistanceBadge(meters: distanceMeters ?? 0)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            openURL()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            // Category icon
            Image(systemName: categoryIcon)
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 20, height: 20)

            // Activity name
            Text(activity.localizedName(language: language))
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Heart button
            Button {
                appState.toggleSavedActivity(activity.id)
            } label: {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isSaved ? .red : .secondary)
            }
            .buttonStyle(.plain)

            // External link indicator
            if activity.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Badges Row

    private var badgesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Indoor/Outdoor badge
                BadgeView(
                    text: activity.indoor
                        ? appState.localized(en: "Indoor", de: "Indoor")
                        : appState.localized(en: "Outdoor", de: "Outdoor"),
                    icon: activity.indoor ? "house.fill" : "sun.max.fill",
                    color: activity.indoor ? .blue : .orange
                )

                // Duration badge
                if let duration = activity.duration {
                    BadgeView(
                        text: duration,
                        icon: "clock",
                        color: .gray
                    )
                }

                // Price badge
                if let price = activity.localizedPrice(language: language) {
                    BadgeView(
                        text: price,
                        icon: "banknote",
                        color: .gray
                    )
                }

                // Free badge
                if activity.isFree {
                    FreeBadge()
                }

                // Age range badge
                if let ageRange = activity.ageRange {
                    BadgeView(
                        text: ageRange,
                        icon: "figure.and.child.holdinghands",
                        color: .purple
                    )
                }

                // Seasonal badge
                if let season = activity.season {
                    BadgeView(
                        text: season.capitalized,
                        icon: seasonIcon(for: season),
                        color: .teal
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var isSaved: Bool {
        appState.savedActivityIDs.contains(activity.id)
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
        default: return "star.fill"
        }
    }

    private func seasonIcon(for season: String) -> String {
        switch season.lowercased() {
        case "winter": return "snowflake"
        case "spring": return "leaf.fill"
        case "summer": return "sun.max.fill"
        case "autumn", "fall": return "leaf.arrow.triangle.circlepath"
        default: return "calendar"
        }
    }

    private var distanceMeters: Double? {
        guard let location, let coordinate = activity.coordinate else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: target)
    }

    private var distanceBadgeText: String? {
        guard let meters = distanceMeters else { return nil }
        return CLLocation.formattedDistance(meters)
    }

    private func openURL() {
        guard let urlString = activity.url,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    let sampleActivity = Activity(
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

    ActivityCard(
        activity: sampleActivity,
        language: .en,
        location: nil
    )
    .padding()
    .environment(AppState())
}
