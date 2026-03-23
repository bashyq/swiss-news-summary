import SwiftUI
import CoreLocation

/// Expanding activity card with accordion behavior.
///
/// **Collapsed**: Compact horizontal row — 76×76 photo thumbnail with category badge,
/// activity name, 2-line description, meta tags (Free/Indoor/Outdoor + distance), chevron.
/// Matches the vcard pattern from CategoryDetailView.
///
/// **Expanded**: Photo panel slides in from top, description un-clamps,
/// detail panel slides in from bottom with 2×2 metadata grid, action buttons.
struct ActivityCard: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toastManager
    @Environment(ReminderManager.self) private var reminderManager

    let activity: Activity
    let language: AppLanguage
    let location: CLLocation?
    @Binding var expandedID: String?

    @State private var showDeleteConfirmation = false
    @State private var showReminderSheet = false
    @State private var showAnchorForm = false
    @State private var markedAsVisited = false

    private var isExpanded: Bool { expandedID == activity.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                // Photo panel — slides in from top when expanded
                photoPanel

                // Expanded core content
                expandedContent

                // Detail panel — slides in from bottom when expanded
                detailPanel
            } else {
                // Compact face (vcard style)
                compactFace
            }
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.znBorder, lineWidth: 1)
        )
        .shadow(
            color: isExpanded ? AppShadow.cardExpanded.color : .clear,
            radius: isExpanded ? AppShadow.cardExpanded.radius : 0,
            x: 0,
            y: isExpanded ? AppShadow.cardExpanded.y : 0
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AppAnimation.spring) {
                if isExpanded {
                    expandedID = nil
                } else {
                    expandedID = activity.id
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
        .confirmationDialog(
            appState.localized(en: "Delete Activity", de: "Aktivität löschen"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.localized(en: "Delete", de: "Löschen"), role: .destructive) {
                appState.deleteCustomActivity(activity.id)
                toastManager.show(
                    appState.localized(en: "Activity deleted", de: "Aktivität gelöscht"),
                    type: .success
                )
            }
        } message: {
            Text(appState.localized(
                en: "Are you sure you want to delete this activity?",
                de: "Möchtest du diese Aktivität wirklich löschen?"
            ))
        }
        .sheet(isPresented: $showReminderSheet) {
            ReminderSheet(activity: activity)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAnchorForm) {
            AnchorFormSheet(
                prefill: AnchorPrefill(
                    title: activity.localizedName(language: language),
                    category: .activity,
                    lat: activity.lat,
                    lon: activity.lon,
                    durationMinutes: 120
                ),
                onSave: { anchor in
                    AnchorStore.shared.add(anchor, for: anchor.startTime)
                    appState.selectedTab = .today
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Accent Bar Color

    private var accentBarColor: Color {
        Color.activityBorderColor(indoor: activity.indoor, isFree: activity.isFree)
    }

    // MARK: - Compact Face (collapsed state)

    private var compactFace: some View {
        HStack(spacing: 0) {
            // Photo thumbnail (76×76)
            compactPhoto
                .padding(10)

            // Body
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.localizedName(language: language))
                    .font(.custom("Playfair", size: 15))
                    .foregroundStyle(.znInk)
                    .lineLimit(1)

                Text(activity.localizedDescription(language: language))
                    .font(.system(size: 11.5, weight: .light))
                    .foregroundStyle(.znBody)
                    .lineLimit(2)
                    .lineSpacing(2)

                // Meta row: price + indoor/outdoor + distance
                HStack(spacing: 6) {
                    if activity.isFree {
                        Text(appState.localized(en: "Free", de: "Gratis"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.znPositive)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(Color.znPositive.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Text(activity.indoor
                        ? appState.localized(en: "Indoor", de: "Indoor")
                        : appState.localized(en: "Outdoor", de: "Outdoor"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.znNavy)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background(Color.znNavy.opacity(0.08))
                        .clipShape(Capsule())

                    Spacer(minLength: 0)

                    if activity.openingHours != nil {
                        VenueStatusBadge(openingHours: activity.openingHours)
                    }

                    if let dist = distanceBadgeText {
                        Text("↗ \(dist)")
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

    // MARK: - Compact Photo Thumbnail

    @ViewBuilder
    private var compactPhoto: some View {
        if !activity.id.hasPrefix("custom-"),
           activity.category.lowercased() != "stayhome",
           let photoURL = APIClient.shared.photoURL(for: activity.id) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        photoFallback
                    default:
                        Rectangle()
                            .fill(Color.znBorder.opacity(0.5))
                            .overlay { ProgressView().tint(.znMuted) }
                    }
                }
                .frame(width: 76, height: 76)
                .clipped()

                // Category badge
                Text(categoryLabel.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.znNavy.opacity(0.82))
                    .clipShape(Capsule())
                    .padding(4)
            }
            .frame(width: 76, height: 76)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            ZStack(alignment: .bottomLeading) {
                photoFallback

                // Category badge
                Text(categoryLabel.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.znNavy.opacity(0.82))
                    .clipShape(Capsule())
                    .padding(4)
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var photoFallback: some View {
        ZStack {
            LinearGradient(
                colors: [accentBarColor.opacity(0.3), Color.znSurface],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundStyle(accentBarColor.opacity(0.5))
        }
    }

    // MARK: - Photo Panel (slides in from top, expanded only)

    @ViewBuilder
    private var photoPanel: some View {
        if isExpanded,
           !activity.id.hasPrefix("custom-"),
           activity.category.lowercased() != "stayhome",
           let photoURL = APIClient.shared.photoURL(for: activity.id) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    // Photo image — tap anywhere on photo to collapse
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 140)
                                .clipped()
                        default:
                            // Placeholder gradient while loading
                            LinearGradient(
                                colors: [accentBarColor.opacity(0.3), Color.znSurface],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 140)
                        }
                    }

                    // Gradient fade into card body
                    LinearGradient(
                        colors: [.clear, Color.znSurface],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 80)

                    // Category badge on photo
                    Text(categoryLabel.uppercased())
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

                // Close button
                Button {
                    withAnimation(AppAnimation.spring) {
                        expandedID = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(AppAnimation.spring) {
                    expandedID = nil
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Expanded Content (title, description, tags, footer)

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            Text(activity.localizedName(language: language))
                .font(.expandedCardTitle)
                .foregroundStyle(Color.znInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 5)

            // Description — full when expanded
            Text(activity.localizedDescription(language: language))
                .font(.system(size: 12.5, weight: .light))
                .foregroundStyle(Color.znBody)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            // Tag pills
            tagsRow
                .padding(.bottom, 10)

            // Footer divider + distance
            footerRow
        }
        .padding(.top, 15)
        .padding(.horizontal, 18)
        .padding(.bottom, 13)
    }

    // MARK: - Tags Row

    private var tagsRow: some View {
        FlowLayout(spacing: 5) {
            // NEW badge
            if activity.isNew {
                tagPill(
                    text: appState.localized(en: "NEW", de: "NEU"),
                    icon: "sparkle",
                    bg: Color.znPositive.opacity(0.1),
                    fg: Color.znPositive
                )
            }

            // Indoor/Outdoor tag
            if activity.indoor {
                tagPill(
                    text: appState.localized(en: "Indoor", de: "Indoor"),
                    icon: "house.fill",
                    bg: Color.znNavy.opacity(0.1),
                    fg: Color.znNavy
                )
            } else {
                tagPill(
                    text: appState.localized(en: "Outdoor", de: "Outdoor"),
                    icon: "sun.max.fill",
                    bg: Color.znTerracotta.opacity(0.1),
                    fg: Color.znTerracotta
                )
            }

            // Free tag
            if activity.isFree {
                tagPill(
                    text: appState.localized(en: "Free", de: "Gratis"),
                    icon: "gift",
                    bg: Color.znPositive.opacity(0.1),
                    fg: Color.znPositive
                )
            }

            // Duration tag
            tagPill(text: activity.duration, icon: "clock", bg: Color.znNeutralTagBg, fg: Color.znNeutralTagText)

            // Opening hours tag
            if let hours = activity.localizedOpeningHours(language: appState.language) {
                tagPill(text: hours, icon: "door.left.hand.open", bg: Color.znNeutralTagBg, fg: Color.znNeutralTagText)
            }

            // Price tag
            if let price = activity.localizedPrice(language: language), !activity.isFree {
                tagPill(text: price, icon: nil, bg: Color.znNeutralTagBg, fg: Color.znNeutralTagText)
            }

            // Seasonal tag
            if let season = activity.season {
                tagPill(
                    text: season.capitalized,
                    icon: seasonIcon(for: season),
                    bg: Color.znNeutralTagBg,
                    fg: Color.znNeutralTagText
                )
            }
        }
    }

    private func tagPill(text: String, icon: String? = nil, bg: Color, fg: Color) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(bg)
        .clipShape(Capsule())
    }

    // MARK: - Footer Row

    private var footerRow: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.znInnerDivider)
                .padding(.bottom, 10)

            HStack(spacing: 10) {
                // Open/Closed status
                if activity.openingHours != nil {
                    VenueStatusBadge(openingHours: activity.openingHours)
                }

                // Distance
                if let meters = distanceMeters {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(CLLocation.formattedDistance(meters))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.znNavy)
                }

                Spacer()
            }
        }
    }

    // MARK: - Detail Panel (slides in from bottom)

    @ViewBuilder
    private var detailPanel: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 0) {
                // Action buttons row: [Directions] [Plan →] [🌐] [♡]
                HStack(spacing: 8) {
                    // Directions button (primary)
                    if let coordinate = activity.coordinate {
                        Button {
                            openDirections(coordinate: coordinate, name: activity.name)
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
                    }

                    // Plan → button (secondary)
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

                    // Website icon button
                    if activity.url != nil {
                        Button {
                            openURL()
                        } label: {
                            Image(systemName: "globe")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.znNavy)
                                .frame(width: 40, height: 40)
                                .background(Color.znNavy.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    // Heart / save icon button
                    Button {
                        appState.toggleSavedActivity(activity.id)
                        let wasSaved = appState.savedActivityIDs.contains(activity.id)
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
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
                }

                // Delete button for custom activities
                if activity.id.hasPrefix("custom-") {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text(appState.localized(en: "Delete", de: "Löschen"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color.znNegative.opacity(0.7))
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                // Mark as visited (toggleable)
                Button {
                    markedAsVisited.toggle()
                    if markedAsVisited {
                        VenueVisitStore.shared.recordVisit(
                            venueId: activity.id,
                            venueName: activity.name,
                            venueType: .activity,
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
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Helpers

    private var isSaved: Bool {
        appState.savedActivityIDs.contains(activity.id)
    }

    private var categoryLabel: String {
        activity.category.capitalized
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

    private func openDirections(coordinate: CLLocationCoordinate2D, name: String? = nil) {
        let urlString = "https://maps.apple.com/directions?destination=\(coordinate.latitude),\(coordinate.longitude)&mode=walking"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Flow Layout (wrapping tag pills)

#Preview {
    struct PreviewWrapper: View {
        @State private var expanded: String? = nil
        var body: some View {
            ScrollView {
                VStack(spacing: 10) {
                    ActivityCard(
                        activity: PreviewData.activity,
                        language: .en,
                        location: nil,
                        expandedID: $expanded
                    )
                }
                .padding()
            }
            .background(Color.znCream)
            .environment(AppState())
            .environment(ToastManager())
            .environment(ReminderManager())
        }
    }
    return PreviewWrapper()
}
