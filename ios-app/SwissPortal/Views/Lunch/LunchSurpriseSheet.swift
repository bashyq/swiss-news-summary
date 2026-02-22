import SwiftUI

/// Sheet displaying a randomly picked lunch spot with playful presentation.
///
/// Shows a large cuisine icon, the spot name, cuisine, badges for lunch/outdoor/vegetarian,
/// and action buttons for trying another, getting directions, or saving.
struct LunchSurpriseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let spot: LunchSpot
    let onTryAnother: () -> Void
    let onSave: () -> Void
    let isSaved: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Large cuisine icon
                    cuisineIcon
                        .padding(.top, 24)

                    // Spot name
                    Text(spot.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Cuisine display
                    Text(spot.cuisineDisplay)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    // Badges
                    badgesRow

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

    private var cuisineIcon: some View {
        ZStack {
            Circle()
                .fill(Color.brand.opacity(0.12))
                .frame(width: 96, height: 96)

            Image(systemName: spot.cuisineSFSymbol)
                .font(.system(size: 40))
                .foregroundStyle(.brand)
        }
    }

    private var badgesRow: some View {
        HStack(spacing: 8) {
            if spot.openForLunch == true {
                BadgeView(
                    text: appState.localized(en: "Open for lunch", de: "Mittagstisch"),
                    icon: "clock",
                    color: .green
                )
            }

            if spot.outdoorSeating == true {
                BadgeView(
                    text: appState.localized(en: "Outdoor", de: "Terrasse"),
                    icon: "sun.max.fill",
                    color: .orange
                )
            }

            if spot.vegetarian == "yes" {
                BadgeView(
                    text: appState.localized(en: "Vegetarian", de: "Vegetarisch"),
                    icon: "leaf",
                    color: .green
                )
            }
        }
    }

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
                .background(LinearGradient.brand)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 12) {
                // Directions button (Apple Maps)
                Button {
                    openInMaps()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                        Text(appState.localized(en: "Directions", de: "Route"))
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private func openInMaps() {
        let urlString = "http://maps.apple.com/?daddr=\(spot.lat),\(spot.lon)&dirflg=w"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    LunchSurpriseSheet(
        spot: LunchSpot(
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
        ),
        onTryAnother: {},
        onSave: {},
        isSaved: false
    )
    .environment(AppState())
}
