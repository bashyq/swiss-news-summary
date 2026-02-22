import SwiftUI
import CoreLocation

/// Card view for a single lunch spot.
///
/// Displays the restaurant name, cuisine icon, cuisine category badge,
/// opening hours, outdoor/vegetarian badges, a heart button for saving,
/// a 5-star rating, and optional distance from the user's location.
/// Tapping the card opens directions in Apple Maps or the website if available.
struct LunchCard: View {
    @Environment(AppState.self) private var appState

    let spot: LunchSpot
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
            // Header: name + cuisine icon + heart button
            headerRow

            // Cuisine category + opening hours
            detailsRow

            // Badges row
            badgesRow

            // Star rating
            starRating

            // Distance badge (if location available)
            if let meters = distanceMeters {
                DistanceBadge(meters: meters)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            openSpot()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            // Cuisine icon
            Image(systemName: spot.cuisineSFSymbol)
                .font(.caption)
                .foregroundStyle(cuisineCategoryColor)
                .frame(width: 20, height: 20)

            // Restaurant name
            Text(spot.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Heart button
            Button {
                appState.toggleSavedLunch(spot.id)
            } label: {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isSaved ? .red : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Details Row

    private var detailsRow: some View {
        HStack(spacing: 8) {
            // Cuisine category badge
            BadgeView(
                text: spot.cuisineDisplay,
                color: cuisineCategoryColor
            )

            // Opening hours
            if let hours = spot.openingHours {
                Text(hours)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // "Open for lunch" green badge
            if spot.openForLunch == true {
                BadgeView(
                    text: appState.localized(en: "Open for lunch", de: "Mittagstisch"),
                    icon: "clock",
                    color: .green
                )
            }
        }
    }

    // MARK: - Badges Row

    private var badgesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Outdoor seating badge
                if spot.outdoorSeating == true {
                    BadgeView(
                        text: appState.localized(en: "Outdoor seating", de: "Aussensitzplatz"),
                        icon: "sun.max.fill",
                        color: .orange
                    )
                }

                // Vegetarian badge
                if spot.vegetarian == true {
                    BadgeView(
                        text: appState.localized(en: "Vegetarian", de: "Vegetarisch"),
                        icon: "leaf",
                        color: .green
                    )
                }

                // Takeaway badge
                if spot.takeaway == true {
                    BadgeView(
                        text: appState.localized(en: "Takeaway", de: "Takeaway"),
                        icon: "bag",
                        color: .blue
                    )
                }

                // Wheelchair accessible badge
                if spot.wheelchair == "yes" {
                    BadgeView(
                        text: appState.localized(en: "Accessible", de: "Barrierefrei"),
                        icon: "figure.roll",
                        color: .teal
                    )
                }
            }
        }
    }

    // MARK: - Star Rating

    private var starRating: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    appState.setLunchRating(spot.id, rating: star)
                } label: {
                    Image(systemName: star <= currentRating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(star <= currentRating ? .orange : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            if currentRating > 0 {
                Text("\(currentRating)/5")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Helpers

    private var isSaved: Bool {
        appState.savedLunchIDs.contains(spot.id)
    }

    private var currentRating: Int {
        appState.lunchRatings[spot.id] ?? 0
    }

    private var cuisineCategoryColor: Color {
        switch spot.cuisineCategory?.lowercased() {
        case "swiss": return .red
        case "italian": return .green
        case "asian": return .orange
        case "kebab": return .brown
        case "cafe": return .purple
        case "vegetarian": return .mint
        case "fastfood": return .yellow
        default: return .blue
        }
    }

    private var distanceMeters: Double? {
        guard let location else { return nil }
        let meters = spot.distance(from: location)
        return meters
    }

    private func openSpot() {
        // Prefer website, fall back to Apple Maps directions
        if let website = spot.website, let url = URL(string: website) {
            UIApplication.shared.open(url)
        } else {
            let urlString = "http://maps.apple.com/?daddr=\(spot.lat),\(spot.lon)&dirflg=w"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

#Preview {
    let sampleSpot = LunchSpot(
        id: "restaurant-1",
        name: "Restaurant Kronenhalle",
        lat: 47.3686,
        lon: 8.5443,
        cuisine: "swiss",
        cuisineCategory: "Swiss",
        wheelchair: "yes",
        outdoorSeating: true,
        takeaway: false,
        openingHours: "Mo-Sa 11:30-14:00",
        openForLunch: true,
        vegetarian: true,
        phone: "+41 44 262 99 00",
        website: "https://www.kronenhalle.ch"
    )

    LunchCard(
        spot: sampleSpot,
        language: .en,
        location: nil
    )
    .padding()
    .environment(AppState())
}
