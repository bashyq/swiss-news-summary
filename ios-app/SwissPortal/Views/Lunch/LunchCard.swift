import SwiftUI
import CoreLocation

/// Card view for a single lunch spot.
///
/// Displays the restaurant name, cuisine icon, cuisine category badge,
/// opening hours, outdoor/vegetarian badges, a website link, a heart button for saving,
/// a 5-star rating, and optional distance from the user's location.
/// Tapping the card triggers `onTap` (typically zooms the map). The safari icon opens the website.
/// Tapping the distance badge opens walking directions in Apple Maps.
struct LunchCard: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toastManager

    let spot: LunchSpot
    let language: AppLanguage
    let location: CLLocation?
    var onTap: (() -> Void)?

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.cuisineBorderColor(spot.cuisineCategory))
                .frame(width: 4)
                .padding(.vertical, 6)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .confirmationDialog(
            appState.localized(en: "Delete Restaurant", de: "Restaurant löschen"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.localized(en: "Delete", de: "Löschen"), role: .destructive) {
                appState.deleteCustomLunch(spot.id)
                toastManager.show(
                    appState.localized(en: "Restaurant deleted", de: "Restaurant gelöscht"),
                    type: .success
                )
            }
        } message: {
            Text(appState.localized(
                en: "Are you sure you want to delete this restaurant?",
                de: "Möchtest du dieses Restaurant wirklich löschen?"
            ))
        }
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

            // Distance badge (if location available) — tapping opens Apple Maps directions
            if let meters = distanceMeters {
                Button {
                    let urlString = "maps://?daddr=\(spot.lat),\(spot.lon)&dirflg=w"
                    if let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    DistanceBadge(meters: meters)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
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
                .font(.system(.subheadline, design: .serif))
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Delete button for custom lunch spots
            if spot.id.hasPrefix("custom-") {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.localized(en: "Delete restaurant", de: "Restaurant löschen"))
            }

            // Website button
            if let website = spot.website, let url = URL(string: website) {
                Link(destination: url) {
                    Image(systemName: "safari")
                        .font(.body)
                        .foregroundStyle(.brand)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(appState.localized(en: "Open website", de: "Webseite öffnen"))
            }

            // Heart button
            Button {
                appState.toggleSavedLunch(spot.id)
                let wasSaved = appState.savedLunchIDs.contains(spot.id)
                toastManager.show(
                    appState.localized(en: wasSaved ? "Saved" : "Removed", de: wasSaved ? "Gespeichert" : "Entfernt"),
                    type: .success
                )
            } label: {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isSaved ? .red : .secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isSaved)
            .accessibilityLabel(appState.localized(
                en: isSaved ? "Remove from saved" : "Save restaurant",
                de: isSaved ? "Aus Gespeicherten entfernen" : "Restaurant speichern"
            ))
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

            // "Open for lunch" green badge / "Closed" gray badge
            if spot.openForLunch == true {
                BadgeView(
                    text: appState.localized(en: "Open for lunch", de: "Mittagstisch"),
                    icon: "clock",
                    color: .green
                )
            } else if spot.openForLunch == false {
                BadgeView(
                    text: appState.localized(en: "Closed", de: "Geschlossen"),
                    icon: "clock.badge.xmark",
                    color: .gray
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
                if spot.vegetarian == "yes" {
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
                    toastManager.show(
                        appState.localized(en: "Rating saved", de: "Bewertung gespeichert"),
                        type: .success
                    )
                } label: {
                    Image(systemName: star <= currentRating ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(star <= currentRating ? .orange : .secondary.opacity(0.4))
                        .frame(minWidth: 32, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(star) \(star == 1 ? (language == .en ? "star" : "Stern") : (language == .en ? "stars" : "Sterne"))")
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
        vegetarian: "yes",
        vegan: nil,
        phone: "+41 44 262 99 00",
        website: "https://www.kronenhalle.ch",
        amenity: "restaurant"
    )

    LunchCard(
        spot: sampleSpot,
        language: .en,
        location: nil
    )
    .padding()
    .environment(AppState())
    .environment(ToastManager())
}
