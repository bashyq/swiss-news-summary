import SwiftUI
import CoreLocation

/// Expanding activity card with accordion behavior.
///
/// **Collapsed**: Category eyebrow, Playfair title, 2-line description, tag pills,
/// footer with distance + "Tap to expand" CTA, 3px left accent bar, background photo wash.
///
/// **Expanded**: Photo panel slides in from top, description un-clamps,
/// detail panel slides in from bottom with 2×2 metadata grid, action buttons.
/// Accent bar fades out when photo is visible.
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
    @State private var markedAsVisited = false

    private var isExpanded: Bool { expandedID == activity.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo panel — slides in from top when expanded
            photoPanel

            // Always-visible core content
            coreContent

            // Detail panel — slides in from bottom when expanded
            detailPanel
        }
        .background {
            // Background photo wash (collapsed only)
            if !isExpanded {
                venuePhotoBackground
            }
            Color.znSurface
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(alignment: .leading) {
            // Left accent bar — fades out when expanded (photo visible)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentBarColor)
                .frame(width: AppSpacing.borderStripWidth)
                .padding(.vertical, 8)
                .opacity(isExpanded ? 0 : 1)
        }
        .shadow(
            color: isExpanded ? AppShadow.cardExpanded.color : AppShadow.card.color,
            radius: isExpanded ? AppShadow.cardExpanded.radius : AppShadow.card.radius,
            x: 0,
            y: isExpanded ? AppShadow.cardExpanded.y : AppShadow.card.y
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExpanded {
                withAnimation(AppAnimation.spring) {
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
    }

    // MARK: - Accent Bar Color

    private var accentBarColor: Color {
        Color.activityBorderColor(indoor: activity.indoor, isFree: activity.isFree)
    }

    // MARK: - Photo Panel (slides in from top)

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
                                .frame(height: 200)
                                .clipped()
                        default:
                            // Placeholder gradient while loading
                            LinearGradient(
                                colors: [accentBarColor.opacity(0.3), Color.znSurface],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 200)
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

    // MARK: - Core Content (always visible)

    private var coreContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: category + title + heart
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    // Category eyebrow — hidden when expanded (shown on photo badge instead)
                    if !isExpanded {
                        Text(categoryLabel.uppercased())
                            .font(.znEyebrow)
                            .tracking(0.9)
                            .foregroundStyle(Color.znMuted)
                    }

                    // Title — grows slightly when expanded
                    Text(activity.localizedName(language: language))
                        .font(isExpanded ? .expandedCardTitle : .compactCardTitle)
                        .foregroundStyle(Color.znInk)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Action buttons row
                HStack(spacing: 0) {
                    // Delete button for custom activities
                    if activity.id.hasPrefix("custom-") {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.znNegative.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Bell button (reminder — only on saved activities)
                    if isSaved {
                        Button {
                            if reminderManager.hasReminder(for: activity.id) {
                                reminderManager.removeReminder(for: activity.id)
                                toastManager.show(
                                    appState.localized(en: "Reminder removed", de: "Erinnerung entfernt"),
                                    type: .success
                                )
                            } else {
                                showReminderSheet = true
                            }
                        } label: {
                            Image(systemName: reminderManager.hasReminder(for: activity.id) ? "bell.fill" : "bell")
                                .font(.caption)
                                .foregroundStyle(reminderManager.hasReminder(for: activity.id) ? .znTerracotta : .znMuted)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Heart button
                    Button {
                        appState.toggleSavedActivity(activity.id)
                        let wasSaved = appState.savedActivityIDs.contains(activity.id)
                        toastManager.show(
                            appState.localized(en: wasSaved ? "Saved" : "Removed", de: wasSaved ? "Gespeichert" : "Entfernt"),
                            type: .success
                        )
                    } label: {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.callout)
                            .foregroundStyle(isSaved ? .znNegative : Color.znBorder)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
                }
            }
            .padding(.bottom, 5)

            // Description — 2-line clamp when collapsed, full when expanded
            Text(activity.localizedDescription(language: language))
                .font(.system(size: 12.5, weight: .light))
                .foregroundStyle(Color.znBody)
                .lineSpacing(3)
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            // Tag pills
            tagsRow
                .padding(.bottom, 10)

            // Footer divider + distance/CTA
            footerRow
        }
        .padding(.top, 15)
        .padding(.horizontal, isExpanded ? 18 : 22)
        .padding(.leading, isExpanded ? 0 : 0) // accent bar space handled by overlay
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

            // Age range tag
            tagPill(text: activity.ageRange, icon: nil, bg: Color.znNeutralTagBg, fg: Color.znNeutralTagText)

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

            HStack {
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

                // CTA hint
                if !isExpanded {
                    HStack(spacing: 3) {
                        Text(appState.localized(en: "Tap to expand", de: "Antippen"))
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.znChevron)
                }
            }
        }
    }

    // MARK: - Detail Panel (slides in from bottom)

    @ViewBuilder
    private var detailPanel: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 0) {
                // Real-time open/closed status
                if activity.openingHours != nil {
                    VenueStatusBadge(openingHours: activity.openingHours)
                        .padding(.bottom, 10)
                }

                // 2×2 metadata grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    detailCell(
                        label: appState.localized(en: "Distance", de: "Entfernung"),
                        value: distanceMeters.map { CLLocation.formattedDistance($0) + " " + appState.localized(en: "away", de: "entfernt") }
                            ?? appState.localized(en: "Unknown", de: "Unbekannt")
                    )
                    detailCell(
                        label: appState.localized(en: "Duration", de: "Dauer"),
                        value: activity.duration
                    )
                    detailCell(
                        label: appState.localized(en: "Price", de: "Preis"),
                        value: activity.localizedPrice(language: language)
                            ?? appState.localized(en: "Not specified", de: "Nicht angegeben")
                    )
                    detailCell(
                        label: appState.localized(en: "Ages", de: "Alter"),
                        value: activity.ageRange
                    )
                }
                .padding(.bottom, 12)

                // Action buttons
                HStack(spacing: 8) {
                    // "Get directions" button
                    if let coordinate = activity.coordinate {
                        Button {
                            openDirections(coordinate: coordinate, name: activity.name)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 13))
                                Text(appState.localized(en: "Get directions", de: "Route"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color.znTerracotta)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Website button
                    if activity.url != nil {
                        Button {
                            openURL()
                        } label: {
                            Image(systemName: "safari")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.znBody)
                                .frame(width: 42, height: 42)
                                .background(Color.znBorder)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Mark as visited
                Button {
                    markedAsVisited = true
                    VenueVisitStore.shared.recordVisit(
                        venueId: activity.id,
                        venueName: activity.name,
                        venueType: .activity,
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
                .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func detailCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(1)
                .foregroundStyle(Color.znMuted)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Color.znInk)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.znCream)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Background Photo Wash (collapsed state)

    @ViewBuilder
    private var venuePhotoBackground: some View {
        if !activity.id.hasPrefix("custom-"),
           activity.category.lowercased() != "stayhome",
           let photoURL = APIClient.shared.photoURL(for: activity.id) {
            AsyncImage(url: photoURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .overlay(Color.znSurface.opacity(0.83))
                }
            }
        }
    }

    // MARK: - Helpers

    private var isSaved: Bool {
        appState.savedActivityIDs.contains(activity.id)
    }

    private var categoryLabel: String {
        let type = activity.indoor
            ? appState.localized(en: "Indoor", de: "Indoor")
            : appState.localized(en: "Outdoor", de: "Outdoor")
        let cat = activity.category.capitalized
        return "\(cat) · \(type)"
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
