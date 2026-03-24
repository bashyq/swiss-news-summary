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
                // Title + prominent open/closed badge
                HStack(spacing: 8) {
                    Text(activity.localizedName(language: language))
                        .font(.custom("PlayfairDisplay-SemiBold", size: 16))
                        .foregroundStyle(.znNavy)
                        .lineLimit(1)

                    if activity.openingHours != nil {
                        VenueStatusBadge(openingHours: activity.openingHours, prominent: true)
                    }
                }

                Text(activity.localizedDescription(language: language))
                    .font(.system(size: 11.5, weight: .light))
                    .foregroundStyle(.znBody)
                    .lineLimit(2)
                    .lineSpacing(2)

                // Meta row: indoor/outdoor + distance
                HStack(spacing: 6) {
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
            ZStack(alignment: .bottomLeading) {
                // Photo image
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
                            colors: [accentBarColor.opacity(0.3), Color.znSurface],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 150)
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
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Expanded Content (title, description, tags, footer)

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title + prominent status
            HStack(spacing: 8) {
                Text(activity.localizedName(language: language))
                    .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                    .foregroundStyle(Color.znNavy)
                    .fixedSize(horizontal: false, vertical: true)

                if activity.openingHours != nil {
                    VenueStatusBadge(openingHours: activity.openingHours, prominent: true)
                }
            }
            .padding(.bottom, 6)

            // Description — full when expanded
            Text(activity.localizedDescription(language: language))
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color.znBody)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            // Quick Info row
            activityQuickInfo
        }
        .padding(.top, 15)
        .padding(.horizontal, 18)
        .padding(.bottom, 13)
    }

    private var activityQuickInfo: some View {
        VenueQuickInfoRow(items: {
            var items: [VenueQuickInfoRow.Item] = []
            items.append(.init(
                icon: "clock",
                label: appState.localized(en: "Duration", de: "Dauer"),
                value: activity.duration
            ))
            if let meters = distanceMeters {
                items.append(.init(
                    icon: "location.fill",
                    label: appState.localized(en: "Distance", de: "Entfernung"),
                    value: CLLocation.formattedDistance(meters)
                ))
            }
            if let price = activity.localizedPrice(language: language), !activity.isFree {
                items.append(.init(
                    icon: "banknote",
                    label: appState.localized(en: "Price", de: "Preis"),
                    value: price
                ))
            } else if activity.isFree {
                items.append(.init(
                    icon: "gift",
                    label: appState.localized(en: "Price", de: "Preis"),
                    value: appState.localized(en: "Free", de: "Gratis")
                ))
            }
            if let todayHours = OpeningHoursParser.todayHours(from: activity.openingHours) {
                items.append(.init(
                    icon: "clock.badge",
                    label: appState.localized(en: "Hours", de: "Zeiten"),
                    value: todayHours
                ))
            }
            return items
        }())
    }

    // MARK: - Detail Panel (slides in from bottom)

    @ViewBuilder
    private var detailPanel: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 0) {
                // Action buttons row
                HStack(spacing: 8) {
                    // Directions — tinted (matches PlanSlotCard)
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
                    if activity.url != nil {
                        Button {
                            openURL()
                        } label: {
                            Image(systemName: "globe")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.znNavy)
                                .frame(width: 40, height: 40)
                                .background(Color.znNavy.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    // Heart — tinted icon
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
                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
