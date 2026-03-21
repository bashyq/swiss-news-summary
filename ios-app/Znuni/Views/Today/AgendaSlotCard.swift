import SwiftUI
import CoreLocation

/// Execution state for a single slot card.
enum SlotExecState {
    case browsing       // Normal interactive mode
    case done           // Completed — collapsed, green accent, 0.5 opacity
    case active         // Currently executing — full opacity, pulsing dot, CTA
    case future         // Not yet reached — 0.75 opacity, minimal info
}

/// Card for a single agenda slot in the timeline.
///
/// Per mockup: 3px left accent bar, type eyebrow, venue name (Playfair 15pt 600),
/// reason text (12pt light), tag pills (FlowLayout), footer (travel note + swap button).
/// Swap tray expands inline below.
///
/// **Tap behavior** (expand-in-place):
/// - Activity slots: photo header, description, detail grid, "Get directions"
/// - Lunch/dinner slots: RestaurantExpandedView (cuisine, price, hours, directions, call)
///
/// **Execution mode** states:
/// - `.done`: collapsed, green accent, "✓ Done" label, 0.5 opacity
/// - `.active`: full opacity, elevated shadow, pulsing terracotta dot, directions CTA, "Done ✓" button
/// - `.future`: 0.75 opacity, type + name + tags only, no reason/swap/CTA
struct AgendaSlotCard: View {
    @Environment(AppState.self) private var appState

    let slot: AgendaSlot
    let accentColor: Color
    @Binding var showSwapTray: Bool
    @Binding var expandedSlotID: String?
    let onSwap: (AgendaSlot.SwapOption) -> Void
    var execState: SlotExecState = .browsing
    var onDone: (() -> Void)?
    var onEdit: (() -> Void)?
    var onSuggestAnother: (() -> Void)?

    // Data for expand views — looked up by venueId
    var activities: [Activity]
    var lunchSpots: [LunchSpot]
    var location: CLLocation?

    /// Whether this is a custom user slot.
    private var isCustomSlot: Bool { slot.source == .userCustom }
    /// Whether this slot is locked.
    private var isLockedSlot: Bool { slot.isLocked }
    /// Whether this is an anchor slot.
    private var isAnchorSlot: Bool { slot.source == .userAnchor }

    private var isExpanded: Bool {
        guard execState == .browsing || execState == .active else { return false }
        return expandedSlotID == slot.id
    }

    /// Resolved activity for activity-type slots
    private var resolvedActivity: Activity? {
        guard slot.type == .activity, let venueId = slot.venueId else { return nil }
        return activities.first { $0.id == venueId }
    }

    /// Resolved restaurant for lunch/dinner slots
    private var resolvedSpot: LunchSpot? {
        guard slot.type == .lunch || slot.type == .dinner, let venueId = slot.venueId else { return nil }
        return lunchSpots.first { $0.id == venueId }
    }

    private var effectiveAccentColor: Color {
        if execState == .done { return .znPositive }
        if isCustomSlot { return .znPositive }
        return accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo panel (expanded)
            activityPhotoPanel
            restaurantPhotoPanel

            // Main card content
            HStack(alignment: .top, spacing: 12) {
                // Timeline dot — vertically centered with first line of text
                ZStack {
                    if slot.type == .homeActivity {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(effectiveAccentColor)
                    } else {
                        Circle()
                            .fill(effectiveAccentColor)
                            .frame(width: 10, height: 10)

                        // Pulsing glow for active
                        if execState == .active {
                            Circle()
                                .fill(Color.znTerracotta.opacity(0.3))
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                .padding(.top, (hasBadge && !isExpanded && (execState == .browsing || execState == .active)) ? 5 : 3)

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    cardContent
                }
            }
            .padding(AppSpacing.cardPadding)

            // Detail panel — activity expand
            activityDetailPanel

            // Detail panel — restaurant expand
            restaurantDetailPanel

            // Active mode: "Done ✓" button
            if execState == .active, let onDone {
                doneButton(onDone)
            }

            // Active mode: full-width directions CTA
            if execState == .active {
                activeDirectionsCTA
            }

            // Swap tray (inline below) — only in browsing mode
            if execState == .browsing, showSwapTray && !slot.swaps.isEmpty {
                SwapTray(swaps: slot.swaps) { swap in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSwapTray = false
                    }
                    onSwap(swap)
                }
            }
        }
        .background(cardBackground)
        .overlay(alignment: .leading) {
            // 3px left accent bar — fades out when expanded (photo visible)
            RoundedRectangle(cornerRadius: 2)
                .fill(effectiveAccentColor)
                .frame(width: AppSpacing.borderStripWidth)
                .opacity(isExpanded ? 0 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(cardBorderStyle, style: cardStrokeStyle)
        )
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
        .opacity(cardOpacity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard execState == .browsing || execState == .active else { return }
            guard !isAnchorSlot else { return }
            guard slot.type == .activity || slot.type == .lunch || slot.type == .dinner else { return }
            withAnimation(AppAnimation.spring) {
                if isExpanded {
                    expandedSlotID = nil
                } else {
                    expandedSlotID = slot.id
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
    }

    // MARK: - Card Styling per Source/State

    private var cardBackground: Color {
        if isCustomSlot {
            return Color.znPositive.opacity(0.03)
        }
        if isAnchorSlot {
            return Color.znNavy.opacity(0.04)
        }
        return Color.znSurface
    }

    private var cardBorderStyle: Color {
        if isCustomSlot {
            return Color.znPositive.opacity(0.35)
        }
        if isAnchorSlot {
            return Color.znNavy.opacity(0.18)
        }
        if isLockedSlot {
            return Color.znNavy.opacity(0.15)
        }
        if execState == .active {
            return Color.znNavy.opacity(0.3)
        }
        return Color.znBorder
    }

    private var cardStrokeStyle: StrokeStyle {
        if isCustomSlot {
            return StrokeStyle(lineWidth: 1.5, dash: [6, 4])
        }
        if slot.type == .homeActivity {
            return StrokeStyle(lineWidth: 1, dash: [6, 3])
        }
        let width: CGFloat = (isLockedSlot || execState == .active) ? 1.5 : 1
        return StrokeStyle(lineWidth: width)
    }

    // MARK: - Opacity & Shadow per State

    private var cardOpacity: Double {
        if slot.isStale { return 0.45 }
        switch execState {
        case .browsing, .active: return 1.0
        case .done: return 0.5
        case .future: return 0.75
        }
    }

    private var shadowColor: Color {
        switch execState {
        case .active: return AppShadow.cardExpanded.color
        case .browsing:
            return isExpanded ? AppShadow.cardExpanded.color : AppShadow.card.color
        default: return AppShadow.card.color
        }
    }

    private var shadowRadius: CGFloat {
        switch execState {
        case .active: return AppShadow.cardExpanded.radius
        case .browsing:
            return isExpanded ? AppShadow.cardExpanded.radius : AppShadow.card.radius
        default: return AppShadow.card.radius
        }
    }

    private var shadowY: CGFloat {
        switch execState {
        case .active: return AppShadow.cardExpanded.y
        case .browsing:
            return isExpanded ? AppShadow.cardExpanded.y : AppShadow.card.y
        default: return AppShadow.card.y
        }
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        switch execState {
        case .done:
            doneContent
        case .future:
            futureContent
        case .browsing, .active:
            browsingContent
        }
    }

    // Done state: "✓ Done" + venue name only
    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(timeDisplay)
                    .font(.znMono)
                    .foregroundStyle(Color.znMuted)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: slot.time)

                Text("·")
                    .foregroundStyle(Color.znMuted)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.znPositive)

                Text(appState.localized(en: "Done", de: "Erledigt"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.znPositive)

                if let weather = slot.weatherAtSlot {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: weather.sfSymbol)
                            .font(.system(size: 10))
                            .symbolRenderingMode(.multicolor)
                        Text("\(weather.temp)°")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.znMuted)
                    }
                }
            }

            Text(slot.venueName)
                .font(.custom("Playfair", size: 15, relativeTo: .body).weight(.semibold))
                .foregroundStyle(Color.znInk)
        }
    }

    // Future state: type + name + tags only
    private var futureContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrowRow

            Text(slot.venueName)
                .font(.custom("Playfair", size: 15, relativeTo: .body).weight(.semibold))
                .foregroundStyle(Color.znInk)

            if !slot.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(slot.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.znNeutralTagText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.znNeutralTagBg)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    /// Whether the badge row has a visible badge (anchor/custom/locked/stale).
    private var hasBadge: Bool {
        isAnchorSlot || isCustomSlot || isLockedSlot || slot.isStale
    }

    // Browsing/Active: full interactive content
    private var browsingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Badge row — only when a badge is visible (avoids empty row for regular slots)
            if !isExpanded, hasBadge {
                HStack(spacing: 6) {
                    if isAnchorSlot {
                        badgePill(text: "📌 Your plans", color: .znNavy)
                    } else if isCustomSlot {
                        badgePill(text: "✏️ Your plans", color: .znPositive)
                    } else if isLockedSlot {
                        badgePill(text: "🔒 Locked", color: .znNavy)
                    } else if slot.isStale {
                        badgePill(text: "⚠️ May need updating", color: .znTerracotta)
                    }

                    Spacer()

                    // ··· edit button alongside badge
                    if execState == .browsing, let onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.znMuted)
                                .frame(width: 28, height: 28)
                                .background(Color.znCream)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Eyebrow: time + type (with edit button when no badge row)
            if !isExpanded {
                eyebrowRow
            }

            // Venue name
            Text(slot.venueName)
                .font(.custom("Playfair", size: isExpanded ? 17 : 15, relativeTo: .body).weight(.semibold))
                .foregroundStyle(Color.znInk)

            // Compact star rating + cuisine + open/closed for restaurant slots (collapsed)
            if !isExpanded, !isCustomSlot, let spot = resolvedSpot, let rating = spot.rating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.znTerracotta)
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.znInk)
                    if let count = spot.ratingCount {
                        Text("(\(count))")
                            .font(.system(size: 10))
                            .foregroundStyle(.znMuted)
                    }
                    Text("·")
                        .foregroundStyle(.znMuted)
                    Text(spot.cuisineDisplay)
                        .font(.system(size: 11))
                        .foregroundStyle(.znMuted)
                    // Inline open/closed status for restaurant slots
                    VenueStatusBadge(
                        openingHours: spot.openingHours,
                        serverOpenForLunch: spot.openForLunch,
                        inline: true
                    )
                }
            }

            // Real-time open/closed status (activity slots only — restaurants handled inline above)
            if !isCustomSlot, !isAnchorSlot, resolvedSpot == nil {
                if let activity = resolvedActivity, activity.openingHours != nil {
                    VenueStatusBadge(openingHours: activity.openingHours)
                }
            }

            // Reason — hidden for custom, locked, and stale slots
            if !isCustomSlot, !isLockedSlot, !slot.isStale, !slot.reason.isEmpty {
                Text(slot.reason)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.znBody)
                    .lineSpacing(2)
                    .lineLimit(isExpanded ? nil : 3)
            }

            // Neighbourhood for custom slots
            if isCustomSlot, let hood = slot.customNeighbourhood {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10))
                    Text(hood)
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.znMuted)
            }

            // Duration (collapsed only)
            if !isExpanded, let duration = slot.durationDisplay {
                Text(duration)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.znMuted)
            }

            // Tags — shown for all except stale
            if !slot.tags.isEmpty, !slot.isStale {
                FlowLayout(spacing: 6) {
                    ForEach(slot.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.znNeutralTagText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.znNeutralTagBg)
                            .clipShape(Capsule())
                    }
                }
            }

            // Footer (browsing only — active mode has its own CTA)
            // Hidden for custom, locked, anchor, and stale slots (no swap/suggest)
            if execState == .browsing, !isCustomSlot, !isLockedSlot, !isAnchorSlot, !slot.isStale {
                footerRow
            }
        }
    }

    // MARK: - Badge Pill

    private func badgePill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
    }

    // MARK: - Eyebrow

    /// Time display string — shows range for anchor slots, start time otherwise.
    private var timeDisplay: String {
        if isAnchorSlot, let endTime = slot.anchorEndTime {
            return "\(slot.time) – \(endTime)"
        }
        return slot.time
    }

    private var eyebrowRow: some View {
        HStack(spacing: 6) {
            Text(timeDisplay)
                .font(.znMono)
                .foregroundStyle(Color.znMuted)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: slot.time)

            Text("·")
                .foregroundStyle(Color.znMuted)

            Text(slot.type.displayName)
                .font(.znEyebrow)
                .foregroundStyle(effectiveAccentColor)

            // Forecasted weather at this slot's time
            if let weather = slot.weatherAtSlot {
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: weather.sfSymbol)
                        .font(.system(size: 11))
                        .symbolRenderingMode(.multicolor)
                    Text("\(weather.temp)°")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.znMuted)
                    if weather.rain {
                        Image(systemName: "umbrella.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.znNavy)
                    }
                }
            }

            // Edit button in eyebrow row when no badge row is shown
            if !hasBadge, execState == .browsing, let onEdit {
                if slot.weatherAtSlot == nil { Spacer() }
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.znMuted)
                        .frame(width: 24, height: 24)
                        .background(Color.znCream)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Footer (browsing only)

    private var footerRow: some View {
        VStack(spacing: 0) {
            if !isExpanded {
                Divider()
                    .overlay(Color.znInnerDivider)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 12) {
                // Distance (activity slots)
                if !isExpanded, let activity = resolvedActivity, let loc = location,
                   let meters = activity.distance(from: loc) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(CLLocation.formattedDistance(meters))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.znNavy)
                }

                // Distance (restaurant slots)
                if !isExpanded, let spot = resolvedSpot, let loc = location {
                    let meters = spot.distance(from: loc)
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(CLLocation.formattedDistance(meters))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.znNavy)
                }

                // Swap button
                if !slot.swaps.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSwapTray.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("⇄")
                                .font(.system(size: 12))
                            Text("\(slot.swaps.count) swaps")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.znTerracotta)
                    }
                    .buttonStyle(.plain)
                }

                // "Suggest another nearby" — lunch/dinner only, browsing mode
                if (slot.type == .lunch || slot.type == .dinner), let onSuggestAnother {
                    Button(action: onSuggestAnother) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                            Text(appState.localized(en: "Another nearby", de: "Andere in Nähe"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.znTerracotta)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Expand hint
                if !isExpanded && (slot.type == .activity || slot.type == .lunch || slot.type == .dinner) {
                    HStack(spacing: 3) {
                        Text(appState.localized(en: "Tap to expand", de: "Antippen"))
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.znChevron)
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Active Mode: Done Button

    private func doneButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                Text(appState.localized(en: "Done", de: "Erledigt"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.znPositive)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.bottom, 8)
    }

    // MARK: - Active Mode: Directions CTA

    @ViewBuilder
    private var activeDirectionsCTA: some View {
        if !isExpanded {
            let hasCoord: Bool = {
                if let a = resolvedActivity, a.coordinate != nil { return true }
                if resolvedSpot != nil { return true }
                return false
            }()

            if hasCoord {
                Button {
                    if let a = resolvedActivity, let coord = a.coordinate {
                        openDirections(lat: coord.latitude, lon: coord.longitude, name: a.name)
                    } else if let s = resolvedSpot {
                        openDirections(lat: s.lat, lon: s.lon, name: s.name)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                            .font(.system(size: 13))
                        Text(appState.localized(en: "Get directions", de: "Route"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.znTerracotta)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.znTerracotta.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
            }
        }
    }

    // MARK: - Activity Photo Panel

    @ViewBuilder
    private var activityPhotoPanel: some View {
        if isExpanded, slot.type == .activity, let activity = resolvedActivity {
            ZStack(alignment: .topTrailing) {
                // Photo
                if !activity.id.hasPrefix("custom-"),
                   activity.category.lowercased() != "stayhome",
                   let photoURL = APIClient.shared.photoURL(for: activity.id) {
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        default:
                            activityPhotoFallback(activity)
                        }
                    }
                } else {
                    activityPhotoFallback(activity)
                }

                // Edit button (replaces close — tap card to collapse)
                if execState == .browsing, let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Restaurant Photo Panel

    @ViewBuilder
    private var restaurantPhotoPanel: some View {
        if isExpanded, (slot.type == .lunch || slot.type == .dinner), let spot = resolvedSpot {
            ZStack(alignment: .topTrailing) {
                // Photo
                if !spot.id.hasPrefix("custom-"),
                   let photoURL = APIClient.shared.photoURL(for: spot.id) {
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                        default:
                            restaurantPhotoFallback(spot)
                        }
                    }
                } else {
                    restaurantPhotoFallback(spot)
                }

                // Edit button (replaces close — tap card to collapse)
                if execState == .browsing, let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func restaurantPhotoFallback(_ spot: LunchSpot) -> some View {
        ZStack {
            LinearGradient(
                colors: [accentColor.opacity(0.7), accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: spot.cuisineSFSymbol)
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(height: 180)
    }

    private func activityPhotoFallback(_ activity: Activity) -> some View {
        ZStack {
            LinearGradient(
                colors: [accentColor.opacity(0.7), accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: activityIcon(for: activity.category))
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(height: 200)
    }

    // MARK: - Activity Detail Panel

    @ViewBuilder
    private var activityDetailPanel: some View {
        if isExpanded, slot.type == .activity, let activity = resolvedActivity {
            VStack(alignment: .leading, spacing: 0) {
                // 2×2 metadata grid
                let language = appState.language
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    detailCell(
                        label: appState.localized(en: "Distance", de: "Entfernung"),
                        value: activityDistanceText(activity)
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
                    if let coordinate = activity.coordinate {
                        Button {
                            openDirections(lat: coordinate.latitude, lon: coordinate.longitude, name: activity.name)
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

                    if activity.url != nil {
                        Button {
                            if let urlString = activity.url, let url = URL(string: urlString) {
                                UIApplication.shared.open(url)
                            }
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
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Restaurant Detail Panel

    @ViewBuilder
    private var restaurantDetailPanel: some View {
        if isExpanded, (slot.type == .lunch || slot.type == .dinner), let spot = resolvedSpot {
            VStack(alignment: .leading, spacing: 12) {
                // Star rating
                if let rating = spot.rating {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.znTerracotta)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.znInk)
                        if let count = spot.ratingCount {
                            Text("(\(count))")
                                .font(.system(size: 12))
                                .foregroundStyle(.znMuted)
                        }
                    }
                }

                // Opening hours
                if let hours = spot.openingHours {
                    openingHoursPill(hours: hours, isOpenForLunch: spot.openForLunch)
                }

                // Metadata grid
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 8) {
                    detailCell(
                        label: appState.localized(en: "Cuisine", de: "Küche"),
                        value: spot.cuisineDisplay
                    )
                    detailCell(
                        label: appState.localized(en: "Price range", de: "Preisklasse"),
                        value: String(repeating: "$", count: spot.priceTier)
                    )
                    if let loc = location {
                        detailCell(
                            label: appState.localized(en: "Distance", de: "Entfernung"),
                            value: CLLocation.formattedDistance(spot.distance(from: loc))
                        )
                    }
                    if spot.wheelchair == "yes" {
                        detailCell(
                            label: appState.localized(en: "Access", de: "Zugang"),
                            value: appState.localized(en: "Wheelchair accessible", de: "Rollstuhlgängig")
                        )
                    }
                }

                // Action buttons
                HStack(spacing: 8) {
                    // Directions
                    Button {
                        openDirections(lat: spot.lat, lon: spot.lon, name: spot.name)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                                .font(.system(size: 12))
                            Text(appState.localized(en: "Get directions", de: "Route"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.znTerracotta)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Call to book
                    if let phone = spot.phone {
                        Button {
                            let cleaned = phone.replacingOccurrences(of: " ", with: "")
                            if let url = URL(string: "tel:\(cleaned)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "phone")
                                    .font(.system(size: 12))
                                Text(appState.localized(en: "Call", de: "Anrufen"))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .foregroundStyle(Color.znNavy)
                            .background(Color.znCream)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.znBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    // Website
                    if let website = spot.website, let url = URL(string: website) {
                        Link(destination: url) {
                            Image(systemName: "globe")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.znBody)
                                .frame(width: 42, height: 42)
                                .background(Color.znCream)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.znBorder, lineWidth: 1))
                        }
                    }
                }

                // Close hint
                Button {
                    withAnimation(AppAnimation.spring) {
                        expandedSlotID = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                        Text(appState.localized(en: "Collapse", de: "Zuklappen"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.znMuted)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Opening Hours Pill

    private func openingHoursPill(hours: String, isOpenForLunch: Bool?) -> some View {
        let lines = LunchCard.splitOpeningHours(hours)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                let venueStatus = OpeningHoursParser.status(from: hours)
                let isOpen = venueStatus == .open || (venueStatus == .unknown && isOpenForLunch == true)
                let isClosed = venueStatus == .closed || (venueStatus == .unknown && isOpenForLunch == false)
                if isOpen {
                    Circle().fill(Color.znPositive).frame(width: 7, height: 7)
                    Text(appState.localized(en: "Open", de: "Geöffnet"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.znPositive)
                } else if isClosed {
                    Circle().fill(Color.znNegative).frame(width: 7, height: 7)
                    Text(appState.localized(en: "Closed", de: "Geschlossen"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.znNegative)
                } else {
                    Circle().fill(Color.znMuted).frame(width: 7, height: 7)
                    Text(appState.localized(en: "Opening hours", de: "Öffnungszeiten"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.znMuted)
                }
            }

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

    // MARK: - Shared Helpers

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

    private func activityDistanceText(_ activity: Activity) -> String {
        guard let loc = location, let meters = activity.distance(from: loc) else {
            return appState.localized(en: "Unknown", de: "Unbekannt")
        }
        return CLLocation.formattedDistance(meters) + " " + appState.localized(en: "away", de: "entfernt")
    }

    private func activityIcon(for category: String) -> String {
        switch category.lowercased() {
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

    private func openDirections(lat: Double, lon: Double, name: String?) {
        // Use venue name for better Apple Maps search; fall back to coordinates
        let destination: String
        if let name, !name.isEmpty {
            destination = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(lat),\(lon)"
        } else {
            destination = "\(lat),\(lon)"
        }
        // dirflg=r = transit directions (more useful than walking for Zürich distances)
        let urlString = "https://maps.apple.com/?daddr=\(destination)&dirflg=r&t=r"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - SlotType Display Name

extension AgendaSlot.SlotType {
    var displayName: String {
        switch self {
        case .activity: return "ACTIVITY"
        case .lunch: return "LUNCH"
        case .dinner: return "DINNER"
        case .homeActivity: return "AT HOME"
        }
    }
}

// MARK: - Accent Color

extension AgendaSlot {
    var accentColor: Color {
        switch type {
        case .activity: return .znNavy
        case .lunch: return .znTerracotta
        case .dinner: return Color(red: 0.482, green: 0.369, blue: 0.655) // #7B5EA7
        case .homeActivity: return Color(red: 0.545, green: 0.412, blue: 0.078) // #8B6914
        }
    }
}
