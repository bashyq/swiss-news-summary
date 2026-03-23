import EventKit

/// Stateless filter: finds calendar events that aren't already anchors
/// and haven't been discarded by the user.
struct CalendarSyncChecker {

    /// Returns calendar events for the given date that are new
    /// (not already imported as anchors, not previously discarded).
    static func newEvents(
        for date: Date,
        existingAnchors: [AnchorEvent],
        store: PlanStoreProvider = LocalPlanStore.shared,
        calendarService: CalendarService = .shared
    ) -> [EKEvent] {
        let events = calendarService.fetchEvents(for: date)
        let existingCalendarIds = Set(existingAnchors.compactMap { $0.calendarEventId })
        let exportedEventIds = Set(store.allExports().values)

        #if DEBUG
        print("📅 CalendarSync: \(events.count) events for \(date), \(existingCalendarIds.count) anchored, \(exportedEventIds.count) exported, \(store.allDiscardedIds().count) discarded")
        for event in events {
            print("   → \(event.title ?? "?") id=\(event.eventIdentifier.prefix(12))... anchored=\(existingCalendarIds.contains(event.eventIdentifier)) exported=\(exportedEventIds.contains(event.eventIdentifier)) discarded=\(store.isDiscarded(eventId: event.eventIdentifier))")
        }
        #endif

        return events.filter { event in
            !existingCalendarIds.contains(event.eventIdentifier) &&
            !exportedEventIds.contains(event.eventIdentifier) &&
            !store.isDiscarded(eventId: event.eventIdentifier)
        }
    }

    /// Check for time overlaps between anchors.
    static func detectConflicts(anchors: [AnchorEvent]) -> [(AnchorEvent, AnchorEvent)] {
        var conflicts: [(AnchorEvent, AnchorEvent)] = []
        for i in 0..<anchors.count {
            for j in (i + 1)..<anchors.count {
                let a = anchors[i]
                let b = anchors[j]
                if a.startTime < b.endTime && b.startTime < a.endTime {
                    conflicts.append((a, b))
                }
            }
        }
        return conflicts
    }
}
