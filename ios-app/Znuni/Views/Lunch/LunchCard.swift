import SwiftUI
import CoreLocation

/// Accordion vcard for a single lunch spot.
///
/// Collapsed face: 94px photo thumbnail + name/rating/status/tags + chevron.
/// Expanded panel: opening hours pill, 2×2 metadata grid, action buttons.
/// Only one card expanded at a time via shared `expandedID` binding.
struct LunchCard: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toastManager

    let spot: LunchSpot
    let language: AppLanguage
    let location: CLLocation?
    @Binding var expandedID: String?
    var onTap: (() -> Void)?

    @State private var showDeleteConfirmation = false
    @State private var showAnchorForm = false
    @State private var markedAsVisited = false

    private var isExpanded: Bool { expandedID == spot.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed face — always visible
            cardFace

            // Expand panel — slides in when expanded
            if isExpanded {
                Divider()
                    .foregroundStyle(Color.znInnerDivider)
                expandPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.znBorder, lineWidth: 1)
        )
        .shadow(
            color: isExpanded ? AppShadow.cardExpanded.color : AppShadow.card.color,
            radius: isExpanded ? AppShadow.cardExpanded.radius : AppShadow.card.radius,
            x: 0,
            y: isExpanded ? AppShadow.cardExpanded.y : AppShadow.card.y
        )
        .opacity(spot.permanentlyClosed == true ? 0.5 : 1.0)
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
        .sheet(isPresented: $showAnchorForm) {
            AnchorFormSheet(
                prefill: AnchorPrefill(
                    title: spot.name,
                    category: .food,
                    lat: spot.lat,
                    lon: spot.lon,
                    address: nil,
                    durationMinutes: 90
                ),
                onSave: { anchor in
                    AnchorStore.shared.add(anchor, for: anchor.startTime)
                    appState.selectedTab = .today
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Card Face (collapsed view)

    private var cardFace: some View {
        HStack(spacing: 0) {
            // Photo thumbnail (94px)
            photoThumbnail

            // Body
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(spot.name)
                    .font(.newsCardHeadline)
                    .foregroundStyle(.znInk)
                    .lineLimit(2)

                // Star rating + open/closed status inline
                HStack(spacing: 6) {
                    starRating
                    lunchStatus
                }

                // Tags + distance
                tagsRow
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, 13)

            Spacer(minLength: 0)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.znChevron)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 34)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AppAnimation.spring) {
                expandedID = isExpanded ? nil : spot.id
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: expandedID)
    }

    // MARK: - Photo Thumbnail

    private var photoThumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            if spot.id.hasPrefix("custom-"),
               let customSpot = CustomLunchSpot.find(spot.id),
               let photo = customSpot.photo {
                // User-added photo for custom restaurants
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 94, height: 100)
                    .clipped()
            } else if !spot.id.hasPrefix("custom-"),
               let photoURL = APIClient.shared.photoURL(for: spot.id) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 94, height: 100)
                            .clipped()
                    case .failure:
                        cuisineGradientFallback
                    default:
                        Rectangle()
                            .fill(Color.znBorder.opacity(0.5))
                            .overlay { ProgressView().tint(.znMuted) }
                    }
                }
            } else {
                cuisineGradientFallback
            }

            // Cuisine badge overlay
            Text(spot.cuisineDisplay)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.04 * 9)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.znNavy.opacity(0.75))
                .clipShape(Capsule())
                .padding(7)
        }
        .frame(width: 94, height: 100)
        .clipped()
    }

    private var cuisineGradientFallback: some View {
        ZStack {
            LinearGradient(
                colors: [cuisineCategoryColor.opacity(0.15), cuisineCategoryColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: spot.cuisineSFSymbol)
                .font(.system(size: 24))
                .foregroundStyle(cuisineCategoryColor.opacity(0.4))
        }
    }

    // MARK: - Star Rating

    @ViewBuilder
    private var starRating: some View {
        if let rating = spot.rating {
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.znTerracotta)
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.znInk)
                if let count = spot.ratingCount {
                    Text("(\(count))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.znMuted)
                }
            }
        } else if spot.id.hasPrefix("custom-"),
                  let customSpot = CustomLunchSpot.find(spot.id),
                  let userRating = customSpot.rating {
            // User's own rating for custom restaurants
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= userRating ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundStyle(star <= userRating ? .znTerracotta : .znBorder)
                }
            }
        }
    }

    // MARK: - Lunch Status

    @ViewBuilder
    private var lunchStatus: some View {
        if spot.permanentlyClosed == true {
            HStack(spacing: 4) {
                Circle().fill(Color.znNegative).frame(width: 6, height: 6)
                Text(appState.localized(en: "Permanently closed", de: "Dauerhaft geschlossen"))
                    .font(.system(size: 10))
                    .foregroundStyle(.znNegative)
            }
        } else {
            VenueStatusBadge(
                openingHours: spot.openingHours,
                serverOpenForLunch: spot.openForLunch
            )
        }
    }

    // MARK: - Tags Row

    private var tagsRow: some View {
        HStack(spacing: 6) {
            // Price tier
            Text(String(repeating: "$", count: spot.priceTier))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.znBody)
            + Text(String(repeating: "$", count: 3 - spot.priceTier))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.znMuted.opacity(0.4))

            // Feature tags
            if spot.outdoorSeating == true {
                vcardTag(
                    text: "☀️ \(appState.localized(en: "Terrace", de: "Terrasse"))",
                    bgColor: Color.znTerracotta.opacity(0.1),
                    textColor: .znTerracotta
                )
            }
            if spot.takeaway == true {
                vcardTag(
                    text: appState.localized(en: "Takeaway", de: "Takeaway"),
                    bgColor: Color.znNavy.opacity(0.08),
                    textColor: .znNavy
                )
            }

            Spacer(minLength: 0)

            // Distance
            if let meters = distanceMeters {
                Text("↗ \(formattedDistance(meters))")
                    .font(.system(size: 10))
                    .foregroundStyle(.znMuted)
            }
        }
        .padding(.top, 2)
    }

    private func vcardTag(text: String, bgColor: Color, textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(bgColor)
            .clipShape(Capsule())
    }

    // MARK: - Expand Panel

    private var expandPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            // Opening hours pill
            if let hours = spot.openingHours {
                openingHoursPill(hours: hours)
            }

            // 2×2 Metadata grid
            metadataGrid

            // Action buttons
            actionButtons

            // Plan around this
            Button {
                showAnchorForm = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 13))
                    Text(appState.localized(en: "Plan around this →", de: "Hiermit planen →"))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.znNavy)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Mark as visited
            Button {
                markedAsVisited = true
                VenueVisitStore.shared.recordVisit(
                    venueId: spot.id,
                    venueName: spot.name,
                    venueType: .restaurant,
                    source: .manualMark
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: markedAsVisited ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 13))
                    Text(markedAsVisited
                         ? appState.localized(en: "Visited", de: "Besucht")
                         : appState.localized(en: "Mark as visited", de: "Als besucht markieren"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(markedAsVisited ? Color.znPositive : Color.znMuted)
            }
            .buttonStyle(.plain)
            .disabled(markedAsVisited)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, 13)
    }

    private func openingHoursPill(hours: String) -> some View {
        let lines = Self.splitOpeningHours(hours)

        return VStack(alignment: .leading, spacing: 6) {
            // Status header — real-time open/closed via client-side parser
            HStack(spacing: 6) {
                let venueStatus = OpeningHoursParser.status(from: hours)
                Circle().fill(venueStatus == .open ? Color.znPositive : Color.znMuted)
                    .frame(width: 7, height: 7)
                Text(venueStatus == .open
                     ? appState.localized(en: "Open now", de: "Jetzt geöffnet")
                     : appState.localized(en: "Opening hours", de: "Öffnungszeiten"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(venueStatus == .open ? .znPositive : .znMuted)
            }

            // Hours listed per day
            VStack(alignment: .leading, spacing: 3) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11))
                        .foregroundStyle(.znBody)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.znCream)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Metadata Grid

    private var metadataGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: 7) {
            metadataCell(
                label: appState.localized(en: "Cuisine", de: "Küche"),
                value: spot.cuisineDisplay
            )
            if let meters = distanceMeters {
                metadataCell(
                    label: appState.localized(en: "Distance", de: "Entfernung"),
                    value: formattedDistance(meters)
                )
            }
            if spot.wheelchair == "yes" {
                metadataCell(
                    label: appState.localized(en: "Access", de: "Zugang"),
                    value: appState.localized(en: "Wheelchair accessible", de: "Rollstuhlgängig")
                )
            }
        }
    }

    private func metadataCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.1 * 9)
                .textCase(.uppercase)
                .foregroundStyle(.znMuted)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.znInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.znCream)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 7) {
            // Directions (primary)
            Button {
                let urlString = "https://maps.apple.com/directions?destination=\(spot.lat),\(spot.lon)&mode=walking"
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        .font(.system(size: 12))
                    Text(appState.localized(en: "Directions", de: "Route"))
                        .font(.system(size: 11.5, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.znTerracotta)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Website (secondary)
            if let website = spot.website, let url = URL(string: website) {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                        Text(appState.localized(en: "Website", de: "Webseite"))
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.znNavy)
                    .background(Color.znCream)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.znBorder, lineWidth: 1))
                }
            }

            // Heart (icon-only)
            Button {
                appState.toggleSavedLunch(spot.id)
                let wasSaved = appState.savedLunchIDs.contains(spot.id)
                toastManager.show(
                    appState.localized(en: wasSaved ? "Saved" : "Removed", de: wasSaved ? "Gespeichert" : "Entfernt"),
                    type: .success
                )
            } label: {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(isSaved ? .znNegative : .znNavy)
                    .frame(width: 38, height: 38)
                    .background(Color.znCream)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.znBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: isSaved)

            // Delete for custom spots
            if spot.id.hasPrefix("custom-") {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.znNegative)
                        .frame(width: 38, height: 38)
                        .background(Color.znCream)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.znBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var isSaved: Bool {
        appState.savedLunchIDs.contains(spot.id)
    }

    private var cuisineCategoryColor: Color {
        Color.cuisineBorderColor(spot.cuisineCategory)
    }

    private var distanceMeters: Double? {
        guard let location else { return nil }
        return spot.distance(from: location)
    }

    private func formattedDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    /// Splits opening hours into per-day lines.
    /// Handles both semicolon-separated ("Mo 09-18; Tu 09-18") and
    /// comma-separated ("Mo-Fr 07:00-23:00, Sa 07:30-22:00") formats.
    static func splitOpeningHours(_ hours: String) -> [String] {
        // First split on semicolons
        let semiParts = hours
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Then split each part on commas followed by a day abbreviation
        let dayPattern = #",\s*(?=(?:Mo|Tu|We|Th|Fr|Sa|Su|PH|Di|Mi|Do)[\s\-])"#
        let regex = try? NSRegularExpression(pattern: dayPattern)

        return semiParts.flatMap { part -> [String] in
            guard let regex else { return [part] }
            let range = NSRange(part.startIndex..., in: part)
            let results = regex.matches(in: part, range: range)
            if results.isEmpty { return [part] }

            var lines: [String] = []
            var lastEnd = part.startIndex
            for match in results {
                let matchRange = Range(match.range, in: part)!
                let segment = String(part[lastEnd..<matchRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                if !segment.isEmpty { lines.append(segment) }
                lastEnd = matchRange.upperBound
            }
            let tail = String(part[lastEnd...]).trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty { lines.append(tail) }
            return lines
        }
    }
}

#Preview {
    @Previewable @State var expandedID: String? = nil

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
        openForDinner: true,
        kidFriendly: true,
        vegetarian: "yes",
        vegan: nil,
        phone: "+41 44 262 99 00",
        website: "https://www.kronenhalle.ch",
        amenity: "restaurant",
        rating: 4.5,
        ratingCount: 2847,
        permanentlyClosed: false
    )

    LunchCard(
        spot: sampleSpot,
        language: .en,
        location: nil,
        expandedID: $expandedID
    )
    .padding()
    .environment(AppState())
    .environment(ToastManager())
}
