import SwiftUI
import os.log
import MapKit

/// Accordion card for a single agenda slot in the Plan tab timeline.
///
/// **Collapsed**: HStack with 76×76 photo thumbnail, eyebrow time/type row,
/// Playfair venue name, reason text, tag pills, footer with distance + expand CTA.
///
/// **Expanded**: Full-width photo, metadata grid, full reason, action buttons.
/// Only one card expanded at a time via shared `expandedID` binding.
struct PlanSlotCard: View {
    let slot: AgendaSlot
    @Binding var expandedID: String?

    /// When true, the card shows a compact saved appearance (muted, no reason/footer).
    var isSaved: Bool = false

    /// ViewModel reference for direct method calls (avoids closure capture issues)
    var viewModel: PlanViewModel?

    // MARK: - Closures (fallback if viewModel not provided)

    var onLock: () -> Void = {}
    var onUnlock: () -> Void = {}
    var onRemove: () -> Void = {}
    var onReplace: () -> Void = {}

    // MARK: - State

    @Environment(AppState.self) private var appState

    private var isExpanded: Bool { expandedID == slot.id }

    private func doLock() {
        Logger(subsystem: "Bashar.Znuni", category: "SlotCard").notice("doLock: \(slot.id) vm=\(viewModel != nil)")
        if let vm = viewModel { vm.lock(slotId: slot.id) } else { onLock() }
    }
    private func doUnlock() {
        Logger(subsystem: "Bashar.Znuni", category: "SlotCard").notice("doUnlock: \(slot.id) vm=\(viewModel != nil)")
        if let vm = viewModel { vm.unlock(slotId: slot.id) } else { onUnlock() }
    }
    private func doRemove() {
        Logger(subsystem: "Bashar.Znuni", category: "SlotCard").notice("doRemove: \(slot.id) vm=\(viewModel != nil)")
        if let vm = viewModel { vm.remove(slotId: slot.id) } else { onRemove() }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                expandedBody
            } else {
                collapsedBody
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(alignment: .leading) {
            if !isExpanded && slot.source != .calendar && slot.type != .homeActivity {
                // Accent bar
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentBarColor)
                    .frame(width: AppSpacing.borderStripWidth)
                    .padding(.vertical, 8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(cardBorderStyle, lineWidth: isHomeActivity ? 1.5 : 1)
        )
        .shadow(
            color: isHomeActivity ? .clear : (isExpanded ? AppShadow.cardExpanded.color : (isSaved ? AppShadow.subtle.color : AppShadow.card.color)),
            radius: isExpanded ? AppShadow.cardExpanded.radius : (isSaved ? AppShadow.subtle.radius : AppShadow.card.radius),
            x: 0,
            y: isExpanded ? AppShadow.cardExpanded.y : (isSaved ? AppShadow.subtle.y : AppShadow.card.y)
        )
        .contextMenu {
            if slot.isLocked {
                Button { doUnlock() } label: { Label("Unlock", systemImage: "lock.open") }
            } else {
                Button { doLock() } label: { Label("Lock this slot", systemImage: "lock") }
            }
            if slot.source != .calendar {
                Button { onReplace() } label: { Label("Replace with my own", systemImage: "pencil") }
            }
            Divider()
            Button(role: .destructive) { doRemove() } label: { Label("Remove", systemImage: "trash") }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
    }

    // MARK: - Collapsed Body

    private var collapsedBody: some View {
        HStack(spacing: 12) {
            // Tappable area for expand/collapse
            HStack(spacing: 12) {
                // Photo thumbnail 76x76
                photoThumbnail
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomLeading) {
                        categoryBadge
                    }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    // Badges (locked / custom)
                    if slot.isLocked || slot.source == .userCustom {
                        badgesRow
                    }

                    // Eyebrow row: time + type + weather
                    eyebrowRow

                    // Venue name
                    Text(slot.venueName)
                        .font(.custom("Playfair", size: 15).weight(.semibold))
                        .foregroundStyle(.znInk)
                        .lineLimit(2)

                    // Reason (2-line clamp) — hidden in saved state
                    if !isSaved && !slot.reason.isEmpty {
                        Text(slot.reason)
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(.znBody)
                            .lineLimit(2)
                    }

                    // Tags — hidden in saved state
                    if !isSaved && !slot.tags.isEmpty {
                        tagsRow(slot.tags)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(AppAnimation.spring) {
                    expandedID = isExpanded ? nil : slot.id
                }
            }

            // Right side: context menu + chevron — NOT part of tap area
            VStack(spacing: 8) {
                if !isSaved {
                    contextMenuButton
                        .frame(width: 24, height: 24)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.znChevron)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .padding(AppSpacing.cardPadding)
    }

    // MARK: - Expanded Body

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width photo (activity/restaurant only)
            if slot.type != .homeActivity && slot.source != .calendar {
                expandedPhoto
            }

            VStack(alignment: .leading, spacing: 12) {
                // Badges row
                badgesRow

                // Eyebrow
                eyebrowRow

                // Venue name
                Text(slot.venueName)
                    .font(.custom("Playfair", size: 17).weight(.semibold))
                    .foregroundStyle(.znInk)

                // Full reason text
                if !slot.reason.isEmpty {
                    Text(slot.reason)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(.znBody)
                }

                // Metadata grid
                metadataGrid

                // Tags
                if !slot.tags.isEmpty {
                    tagsRow(slot.tags)
                }

                // Action buttons
                actionButtons
            }
            .padding(AppSpacing.cardPadding)
        }
    }

    // MARK: - Photo Thumbnail (76x76)

    @ViewBuilder
    private var photoThumbnail: some View {
        if isHomeActivity {
            // Stay-at-home: no gradient, just icon
            ZStack {
                Color.znSurface
                Text(homeEmoji)
                    .font(.system(size: 28))
            }
        } else if slot.source == .calendar {
            // Calendar: blue gradient + calendar icon
            ZStack {
                LinearGradient(
                    colors: [Color.znNavy.opacity(0.3), Color.znNavy.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "calendar")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
        } else if slot.source == .userCustom {
            // Custom: positive gradient + pencil icon
            ZStack {
                LinearGradient(
                    colors: [Color.znPositive.opacity(0.3), Color.znPositive.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "pencil")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
        } else if let venueId = slot.venueId {
            // Activity/restaurant with R2 photo
            AsyncImage(url: APIClient.shared.photoURL(for: venueId)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    categoryGradientFallback
                }
            }
        } else {
            categoryGradientFallback
        }
    }

    private var categoryGradientFallback: some View {
        ZStack {
            LinearGradient(
                colors: slotGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: slotIconName)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Expanded Photo (160pt)

    private var expandedPhoto: some View {
        Group {
            if let venueId = slot.venueId {
                AsyncImage(url: APIClient.shared.photoURL(for: venueId)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(height: 160)
                            .clipped()
                    default:
                        expandedPhotoFallback
                    }
                }
            } else {
                expandedPhotoFallback
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .clipped()
    }

    private var expandedPhotoFallback: some View {
        ZStack {
            LinearGradient(
                colors: slotGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: slotIconName)
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Category Badge

    @ViewBuilder
    private var categoryBadge: some View {
        if !isHomeActivity {
            Text(slotTypeShortLabel)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.znNavy.opacity(0.82))
                .clipShape(Capsule())
                .padding(4)
        }
    }

    // MARK: - Eyebrow Row

    private var eyebrowRow: some View {
        HStack(spacing: 4) {
            // Time
            Text(slot.time)
                .font(.znMono)
                .foregroundStyle(.znMuted)
                .monospacedDigit()

            if let endTime = slot.anchorEndTime {
                Text("– \(endTime)")
                    .font(.znMono)
                    .foregroundStyle(.znMuted)
            }

            Text("\u{00B7}")
                .foregroundStyle(.znMuted)

            // Type label
            Text(slotTypeShortLabel.uppercased())
                .font(.znEyebrow)
                .tracking(0.5)
                .foregroundStyle(typeColor)

            // Weather
            if let weather = slot.weatherAtSlot {
                Spacer().frame(width: 4)
                Image(systemName: weather.sfSymbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 11))
                Text("\(weather.temp)\u{00B0}")
                    .font(.system(size: 11))
                    .foregroundStyle(.znMuted)
            }
        }
    }

    // MARK: - Badges Row

    private var badgesRow: some View {
        HStack(spacing: 8) {
            if slot.isLocked {
                HStack(spacing: 3) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("Locked")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.znNavy)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.znNavy.opacity(0.08))
                .clipShape(Capsule())
            }

            if slot.source == .userCustom {
                HStack(spacing: 3) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                    Text("Custom")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.znPositive)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.znPositive.opacity(0.08))
                .clipShape(Capsule())
            }

            Spacer()
        }
    }

    // MARK: - Tags Row

    private func tagsRow(_ tags: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(tags.prefix(4), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tagTextColor(tag))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tagBgColor(tag))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Metadata Grid (expanded)

    private var metadataGrid: some View {
        let items: [(label: String, value: String)] = {
            var result: [(String, String)] = []
            if slot.travelNote != nil || slot.lat != nil {
                result.append(("Distance", slot.travelNote ?? "Nearby"))
            }
            if let duration = slot.durationDisplay {
                result.append(("Duration", duration))
            } else if let mins = slot.durationMinutes {
                result.append(("Duration", "\(mins) min"))
            }
            if slot.source == .calendar, let endTime = slot.anchorEndTime {
                result.append(("Until", endTime))
            }
            return result
        }()

        return Group {
            if !items.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 10) {
                    ForEach(items, id: \.label) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label.uppercased())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.znMuted)
                            Text(item.value)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.znInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(Color.znCream.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Action Buttons (expanded)

    private var actionButtons: some View {
        HStack(spacing: 10) {
            if slot.lat != nil && slot.lon != nil {
                Button {
                    openDirections()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text("Directions")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.znTerracotta)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.znTerracotta.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if slot.venueId != nil {
                Button {
                    // Website would be looked up from activity data
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                        Text("Website")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.znNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.znNavy.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Context Menu Button

    private var contextMenuButton: some View {
        Menu {
            if slot.isLocked {
                Button { doUnlock() } label: { Label("Unlock", systemImage: "lock.open") }
            } else {
                Button { doLock() } label: { Label("Lock this slot", systemImage: "lock") }
            }
            if slot.source != .calendar {
                Button { onReplace() } label: { Label("Replace with my own", systemImage: "pencil") }
            }
            Divider()
            Button(role: .destructive) { doRemove() } label: { Label("Remove", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14))
                .foregroundStyle(.znMuted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Helpers

    private var isHomeActivity: Bool {
        slot.type == .homeActivity
    }

    private var accentBarColor: Color {
        switch slot.source {
        case .calendar: return .znNavy
        case .userCustom: return .znPositive
        default:
            switch slot.type {
            case .activity: return .znTerracotta
            case .lunch, .dinner: return .znPositive
            case .homeActivity: return .clear
            }
        }
    }

    private var typeColor: Color {
        switch slot.source {
        case .calendar: return .znNavy
        case .userCustom: return .znPositive
        default:
            switch slot.type {
            case .activity, .homeActivity: return .znTerracotta
            case .lunch, .dinner: return .znPositive
            }
        }
    }

    private var cardBackground: Color {
        switch slot.source {
        case .calendar: return Color.znNavy.opacity(0.04)
        case .userCustom: return Color.znPositive.opacity(0.03)
        default: return .znSurface
        }
    }

    private var cardBorderStyle: some ShapeStyle {
        if isHomeActivity {
            return Color.znBorder
        }
        return Color.znBorder.opacity(0.6)
    }

    private var slotGradientColors: [Color] {
        switch slot.type {
        case .activity: return [.znTerracotta.opacity(0.4), .znTerracotta.opacity(0.7)]
        case .lunch: return [.znPositive.opacity(0.4), .znPositive.opacity(0.7)]
        case .dinner: return [.znNavy.opacity(0.4), .znNavy.opacity(0.7)]
        case .homeActivity: return [.znMuted.opacity(0.2), .znMuted.opacity(0.4)]
        }
    }

    private var slotIconName: String {
        switch slot.type {
        case .activity: return "star.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "wineglass.fill"
        case .homeActivity: return "house.fill"
        }
    }

    private var slotTypeShortLabel: String {
        switch slot.type {
        case .activity: return "Activity"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .homeActivity: return "At Home"
        }
    }

    private var homeEmoji: String {
        // Rotate based on slot id for variety
        let emojis = ["🏠", "🎨", "🧩", "📚"]
        let hash = abs(slot.id.hashValue) % emojis.count
        return emojis[hash]
    }

    private func tagTextColor(_ tag: String) -> Color {
        let lower = tag.lowercased()
        if lower.contains("outdoor") { return .znTerracotta }
        if lower.contains("indoor") { return .znNavy }
        if lower.contains("free") { return .znPositive }
        return .znNeutralTagText
    }

    private func tagBgColor(_ tag: String) -> Color {
        let lower = tag.lowercased()
        if lower.contains("outdoor") { return .znTerracotta.opacity(0.10) }
        if lower.contains("indoor") { return .znNavy.opacity(0.08) }
        if lower.contains("free") { return .znPositive.opacity(0.10) }
        return .znNeutralTagBg
    }

    private func openDirections() {
        guard let lat = slot.lat, let lon = slot.lon else { return }
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = slot.venueName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}
