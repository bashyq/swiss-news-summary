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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        // Cuisine icon
                        cuisineIcon
                            .padding(.top, 12)

                        // Spot name
                        Text(spot.name)
                            .font(.custom("Playfair", size: 22).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Cuisine display
                        Text(spot.cuisineDisplay)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Badges
                        badgesRow

                        // Opening hours
                        if let hours = spot.openingHours, !hours.isEmpty {
                            openingHoursView(hours)
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

    @ViewBuilder
    private var cuisineIcon: some View {
        if spot.id.hasPrefix("custom-"),
           let customSpot = CustomLunchSpot.find(spot.id),
           let photo = customSpot.photo {
            // User's photo for custom restaurants
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if !spot.id.hasPrefix("custom-"),
           let photoURL = APIClient.shared.photoURL(for: spot.id) {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                case .failure:
                    cuisineIconFallback
                default:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.znBorder)
                        .frame(width: 120, height: 120)
                        .overlay { ProgressView() }
                }
            }
        } else {
            cuisineIconFallback
        }
    }

    private var cuisineIconFallback: some View {
        ZStack {
            Circle()
                .fill(Color.brand.opacity(0.12))
                .frame(width: 72, height: 72)

            Image(systemName: spot.cuisineSFSymbol)
                .font(.system(size: 30))
                .foregroundStyle(.brand)
        }
    }

    private var badgesRow: some View {
        HStack(spacing: 8) {
            if spot.openForLunch == true {
                BadgeView(
                    text: appState.localized(en: "Open for lunch", de: "Mittagstisch"),
                    icon: "clock",
                    color: .znPositive
                )
            }

            if spot.outdoorSeating == true {
                BadgeView(
                    text: appState.localized(en: "Outdoor", de: "Terrasse"),
                    icon: "sun.max.fill",
                    color: .znTerracotta
                )
            }


        }
    }

    private func openingHoursView(_ hours: String) -> some View {
        let lines = LunchCard.splitOpeningHours(hours)
        return VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.znMuted)
                Text(appState.localized(en: "Opening hours", de: "Öffnungszeiten"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.znMuted)
            }
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 12))
                    .foregroundStyle(.znBody)
            }
        }
        .padding(.horizontal, 24)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary row: Website + Directions + Save
            HStack(spacing: 8) {
                // Website button
                if let urlString = spot.website, let url = URL(string: urlString) {
                    Link(destination: url) {
                        actionPill(icon: "safari", label: appState.localized(en: "Website", de: "Webseite"))
                    }
                }

                // Directions button (Apple Maps)
                Button(action: openInMaps) {
                    actionPill(icon: "arrow.triangle.turn.up.right.diamond", label: appState.localized(en: "Directions", de: "Route"))
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
            amenity: "restaurant",
            rating: 4.5,
            ratingCount: 2847,
            permanentlyClosed: false
        ),
        onTryAnother: {},
        onSave: {},
        isSaved: false
    )
    .environment(AppState())
}
