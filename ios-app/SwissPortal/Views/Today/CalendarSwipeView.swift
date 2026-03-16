import SwiftUI
import EventKit

// MARK: - Category Inference

/// Infer an AnchorCategory from a calendar event title using EN + DE keywords.
private func inferCategory(from title: String?) -> AnchorCategory {
    guard let t = title?.lowercased() else { return .other }

    let foodKeywords = ["lunch", "dinner", "brunch", "restaurant", "café", "cafe",
                        "mittagessen", "abendessen", "znüni", "zvieri"]
    if foodKeywords.contains(where: { t.contains($0) }) { return .food }

    let socialKeywords = ["birthday", "party", "playdate",
                          "geburtstag", "spieldate", "feier"]
    if socialKeywords.contains(where: { t.contains($0) }) { return .social }

    let activityKeywords = ["sport", "class", "gym", "swim", "football",
                            "training", "schwimmen", "turnen", "kurs"]
    if activityKeywords.contains(where: { t.contains($0) }) { return .activity }

    let errandKeywords = ["appointment", "doctor", "errand", "shop",
                          "arzt", "einkaufen", "termin", "zahnarzt"]
    if errandKeywords.contains(where: { t.contains($0) }) { return .errand }

    return .other
}

// MARK: - EKEvent → AnchorEvent

extension EKEvent {
    func toAnchorEvent() -> AnchorEvent {
        AnchorEvent(
            id: UUID(),
            title: self.title ?? "Calendar event",
            category: inferCategory(from: self.title),
            startTime: self.startDate,
            durationMinutes: Int(self.endDate.timeIntervalSince(self.startDate) / 60),
            source: .calendar,
            calendarEventId: self.eventIdentifier,
            createdDate: Date()
        )
    }
}

// MARK: - CalendarSwipeView

/// Full-screen modal with Tinder-style card stack for accepting/discarding calendar events.
struct CalendarSwipeView: View {
    let events: [EKEvent]
    let planDate: Date
    let onComplete: ([AnchorEvent]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var acceptedAnchors: [AnchorEvent] = []
    @State private var dragOffset: CGSize = .zero
    @State private var showBuildingOverlay = false

    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            Color.znCream.ignoresSafeArea()

            if showBuildingOverlay {
                buildingOverlay
            } else if currentIndex < events.count {
                cardStack
            }
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            // Header
            VStack {
                swipeHeader
                Spacer()
            }

            // Side icons
            HStack {
                // Trash icon (left)
                Image(systemName: "trash.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red.opacity(trashIconOpacity))
                    .scaleEffect(trashIconScale)
                    .padding(.leading, 32)

                Spacer()

                // Calendar icon (right)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.green.opacity(calendarIconOpacity))
                    .scaleEffect(calendarIconScale)
                    .padding(.trailing, 32)
            }

            // Card stack — show next card behind
            ZStack {
                if currentIndex + 1 < events.count {
                    eventCard(for: events[currentIndex + 1])
                        .scaleEffect(0.95)
                        .offset(y: 8)
                }

                eventCard(for: events[currentIndex])
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 20))
                    .overlay(
                        ZStack {
                            // Green tint on right swipe
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.green.opacity(greenTintOpacity))

                            // Red tint on left swipe
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.red.opacity(redTintOpacity))
                        }
                    )
                    .gesture(dragGesture)
            }
            .padding(.top, 80)

            // Counter at bottom
            VStack {
                Spacer()
                Text("\(currentIndex + 1) of \(events.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.znMuted)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Event Card

    private func eventCard(for event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event title
            Text(event.title ?? "Calendar event")
                .font(.custom("Playfair-VariableFont_opsz,wdth,wght", size: 22))
                .foregroundStyle(Color.znInk)
                .lineLimit(2)

            // Time range
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.znMuted)
                Text(timeRangeString(event))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.znBody)
            }

            // Calendar name
            if let calendarTitle = event.calendar?.title {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(cgColor: event.calendar.cgColor))
                        .frame(width: 8, height: 8)
                    Text(calendarTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.znMuted)
                }
            }

            // Duration chip
            HStack {
                Spacer()
                Text(durationString(event))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.znNavy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.znNavy.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Category inference hint
            let category = inferCategory(from: event.title)
            if category != .other {
                HStack(spacing: 4) {
                    Text(category.emoji)
                    Text(category.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.znMuted)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.znBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, 24)
    }

    // MARK: - Swipe Header

    private var swipeHeader: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Text("CALENDAR SYNC")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.znMuted)

                Text("Swipe to add to your day")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.znBody)
            }
            .frame(maxWidth: .infinity)

            Button {
                onComplete(acceptedAnchors)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.znMuted)
                    .frame(width: 32, height: 32)
                    .background(Color.znBorder.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.trailing, 20)
        }
        .padding(.top, 20)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                if value.translation.width > swipeThreshold {
                    acceptEvent()
                } else if value.translation.width < -swipeThreshold {
                    discardEvent()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Actions

    private func acceptEvent() {
        let event = events[currentIndex]
        let anchor = event.toAnchorEvent()
        acceptedAnchors.append(anchor)

        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: 500, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dragOffset = .zero
            advanceToNext()
        }
    }

    private func discardEvent() {
        let event = events[currentIndex]
        CalendarDiscardStore.shared.discard(event.eventIdentifier)

        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: -500, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dragOffset = .zero
            advanceToNext()
        }
    }

    private func advanceToNext() {
        if currentIndex + 1 < events.count {
            currentIndex += 1
        } else {
            // All cards swiped
            if !acceptedAnchors.isEmpty {
                showBuildingOverlay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete(acceptedAnchors)
                    dismiss()
                }
            } else {
                // All discarded — just dismiss
                onComplete([])
                dismiss()
            }
        }
    }

    // MARK: - Building Overlay

    private var buildingOverlay: some View {
        ZStack {
            Color.znNavy.ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)

                Text("Building your day")
                    .font(.custom("Playfair-VariableFont_opsz,wdth,wght", size: 24))
                    .foregroundStyle(.white)

                Text("\(acceptedAnchors.count) event\(acceptedAnchors.count == 1 ? "" : "s") added")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Opacity / Scale Helpers

    private var greenTintOpacity: Double {
        dragOffset.width > 0 ? min(Double(dragOffset.width) / 200, 0.15) : 0
    }

    private var redTintOpacity: Double {
        dragOffset.width < 0 ? min(Double(-dragOffset.width) / 200, 0.15) : 0
    }

    private var calendarIconOpacity: Double {
        dragOffset.width > 0 ? min(Double(dragOffset.width) / 100, 1.0) : 0.2
    }

    private var calendarIconScale: CGFloat {
        dragOffset.width > 0 ? min(1.0 + CGFloat(dragOffset.width) / 300, 1.4) : 1.0
    }

    private var trashIconOpacity: Double {
        dragOffset.width < 0 ? min(Double(-dragOffset.width) / 100, 1.0) : 0.2
    }

    private var trashIconScale: CGFloat {
        dragOffset.width < 0 ? min(1.0 + CGFloat(-dragOffset.width) / 300, 1.4) : 1.0
    }

    // MARK: - Formatting Helpers

    private func timeRangeString(_ event: EKEvent) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }

    private func durationString(_ event: EKEvent) -> String {
        let minutes = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            if remainder == 0 { return "\(hours) hr\(hours > 1 ? "s" : "")" }
            return "\(hours) hr \(remainder) min"
        }
        return "\(minutes) min"
    }
}
