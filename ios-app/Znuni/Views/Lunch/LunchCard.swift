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
            if isExpanded {
                // Expanded: photo panel + content + detail panel (matches ActivityCard)
                photoPanel
                expandedContent
                detailPanel
            } else {
                // Collapsed: compact face
                cardFace
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
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AppAnimation.spring) {
                expandedID = isExpanded ? nil : spot.id
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
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
            // Photo thumbnail (76×76) — matches ActivityCard
            photoThumbnail
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(10)

            // Body
            VStack(alignment: .leading, spacing: 4) {
                // Title + prominent open/closed badge
                HStack(spacing: 8) {
                    Text(spot.name)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 16))
                        .foregroundStyle(.znNavy)
                        .lineLimit(1)

                    if spot.permanentlyClosed != true {
                        VenueStatusBadge(
                            openingHours: spot.openingHours,
                            serverOpenForLunch: spot.openForLunch,
                            prominent: true
                        )
                    }
                }

                // Description (generated)
                Text(spot.generatedDescription(language: language))
                    .font(.system(size: 11.5, weight: .light))
                    .foregroundStyle(.znBody)
                    .lineLimit(2)
                    .lineSpacing(2)

                // Meta row: rating + tags + distance
                HStack(spacing: 6) {
                    // Star rating inline
                    if let rating = spot.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.znTerracotta)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.znInk)
                        }
                    }

                    if spot.outdoorSeating == true {
                        Text(appState.localized(en: "Terrace", de: "Terrasse"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.znNeutralTagText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(Color.znNeutralTagBg)
                            .clipShape(Capsule())
                    }

                    if spot.takeaway == true {
                        Text(appState.localized(en: "Takeaway", de: "Takeaway"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.znNeutralTagText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(Color.znNeutralTagBg)
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)

                    if let meters = distanceMeters {
                        Text("↗ \(formattedDistance(meters))")
                            .font(.system(size: 10))
                            .foregroundStyle(.znMuted)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.leading, 4)
            .padding(.trailing, 4)
            .padding(.vertical, 13)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.znChevron)
                .frame(width: 34)
        }
    }

    // MARK: - Photo Thumbnail

    @ViewBuilder
    private var photoThumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            if spot.id.hasPrefix("custom-"),
               let customSpot = CustomLunchSpot.find(spot.id),
               let photo = customSpot.photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 76, height: 76)
                    .clipped()
            } else if !spot.id.hasPrefix("custom-"),
               let photoURL = APIClient.shared.photoURL(for: spot.id) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 76, height: 76)
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
            Text(spot.cuisineDisplay.uppercased())
                .font(.system(size: 7, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.znNavy.opacity(0.82))
                .clipShape(Capsule())
                .padding(4)
        }
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

    // MARK: - Photo Panel (expanded, matches ActivityCard)

    @ViewBuilder
    private var photoPanel: some View {
        ZStack(alignment: .bottomLeading) {
            if spot.id.hasPrefix("custom-"),
               let customSpot = CustomLunchSpot.find(spot.id),
               let photo = customSpot.photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipped()
            } else if !spot.id.hasPrefix("custom-"),
                      let photoURL = APIClient.shared.photoURL(for: spot.id) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .clipped()
                    default:
                        LinearGradient(
                            colors: [cuisineCategoryColor.opacity(0.3), Color.znSurface],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 150)
                    }
                }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [cuisineCategoryColor.opacity(0.3), Color.znSurface],
                        startPoint: .top, endPoint: .bottom
                    )
                    Image(systemName: spot.cuisineSFSymbol)
                        .font(.system(size: 36))
                        .foregroundStyle(cuisineCategoryColor.opacity(0.5))
                }
                .frame(height: 150)
            }

            // Gradient fade into card body
            LinearGradient(
                colors: [.clear, Color.znSurface],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 80)

            // Cuisine badge on photo
            Text(spot.cuisineDisplay.uppercased())
                .font(.znEyebrow)
                .tracking(0.8)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.znNavy.opacity(0.82))
                .clipShape(Capsule())
                .padding(.leading, 14)
                .padding(.bottom, 62)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Expanded Content (title, rating, quick info)

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title + prominent status
            HStack(spacing: 8) {
                Text(spot.name)
                    .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                    .foregroundStyle(Color.znNavy)
                    .fixedSize(horizontal: false, vertical: true)

                if spot.permanentlyClosed != true {
                    VenueStatusBadge(
                        openingHours: spot.openingHours,
                        serverOpenForLunch: spot.openForLunch,
                        prominent: true
                    )
                }
            }
            .padding(.bottom, 6)

            // Generated description
            Text(spot.generatedDescription(language: language))
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color.znBody)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            // Star rating
            starRating
                .padding(.bottom, 12)

            // Quick Info row
            restaurantQuickInfo
        }
        .padding(.top, 15)
        .padding(.horizontal, 18)
        .padding(.bottom, 13)
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


    // MARK: - Detail Panel (slides in from bottom)

    @ViewBuilder
    private var detailPanel: some View {
        if isExpanded {
        VStack(alignment: .leading, spacing: 0) {
            // Action buttons
            HStack(spacing: 8) {
                // Directions — tinted (matches PlanSlotCard)
                Button {
                    let urlString = "https://maps.apple.com/directions?destination=\(spot.lat),\(spot.lon)&mode=walking"
                    if let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(appState.localized(en: "Directions", de: "Route"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.znTerracotta)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.znTerracotta.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Plan → — tinted (matches PlanSlotCard)
                Button {
                    showAnchorForm = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 12))
                        Text(appState.localized(en: "Plan →", de: "Planen →"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.znNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.znNavy.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Website — tinted icon
                if let website = spot.website, let url = URL(string: website) {
                    Link(destination: url) {
                        Image(systemName: "globe")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.znNavy)
                            .frame(width: 40, height: 40)
                            .background(Color.znNavy.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Heart — tinted icon
                Button {
                    appState.toggleSavedLunch(spot.id)
                    let wasSaved = appState.savedLunchIDs.contains(spot.id)
                    toastManager.show(
                        appState.localized(en: wasSaved ? "Saved" : "Removed", de: wasSaved ? "Gespeichert" : "Entfernt"),
                        type: .success
                    )
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundStyle(isSaved ? Color.znTerracotta : Color.znNavy)
                        .frame(width: 40, height: 40)
                        .background(isSaved ? Color.znTerracotta.opacity(0.12) : Color.znNavy.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                            .frame(width: 40, height: 40)
                            .background(Color.znNegative.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Mark as visited (toggleable)
            Button {
                markedAsVisited.toggle()
                if markedAsVisited {
                    VenueVisitStore.shared.recordVisit(
                        venueId: spot.id,
                        venueName: spot.name,
                        venueType: .restaurant,
                        source: .manualMark
                    )
                }
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
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var restaurantQuickInfo: some View {
        VenueQuickInfoRow(items: {
            var items: [VenueQuickInfoRow.Item] = []
            if let rating = spot.rating {
                let value = spot.ratingCount.map { "\(String(format: "%.1f", rating)) (\($0))" }
                    ?? String(format: "%.1f", rating)
                items.append(.init(icon: "star.fill", label: appState.localized(en: "Rating", de: "Bewertung"), value: value))
            }
            if let meters = distanceMeters {
                items.append(.init(icon: "location.fill", label: appState.localized(en: "Distance", de: "Entfernung"), value: formattedDistance(meters)))
            }
            items.append(.init(
                icon: "banknote",
                label: appState.localized(en: "Price", de: "Preis"),
                value: String(repeating: "$", count: spot.priceTier)
            ))
            if let todayHours = OpeningHoursParser.todayHours(from: spot.openingHours) {
                items.append(.init(
                    icon: "clock.badge",
                    label: appState.localized(en: "Hours", de: "Zeiten"),
                    value: todayHours
                ))
            }
            return items
        }())
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
