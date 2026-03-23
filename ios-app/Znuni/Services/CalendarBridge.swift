import EventKit
import CoreLocation

/// Unified calendar read/write wrapper for the Plan tab.
/// Uses PlanStoreProvider for discard/export tracking instead of separate stores.
@Observable
final class CalendarBridge {

    // MARK: - Dependencies

    private let calendarService = CalendarService.shared
    private let store: PlanStoreProvider

    init(store: PlanStoreProvider = LocalPlanStore.shared) {
        self.store = store
    }

    // MARK: - Access

    /// Whether the app has full calendar access.
    var hasAccess: Bool {
        calendarService.hasAccess
    }

    /// Request full calendar access (iOS 17+).
    func requestAccess() async -> Bool {
        await calendarService.requestAccess()
    }

    // MARK: - Read

    /// Fetch non-all-day calendar events for a date, excluding discarded
    /// and Znuni-exported events.
    func fetchEvents(for date: Date) -> [CalendarSlot] {
        guard hasAccess else { return [] }

        let ekEvents = calendarService.fetchEvents(for: date)
        let discardedIds = store.allDiscardedIds()
        let exportedIds = Set(store.allExports().values)

        return ekEvents.compactMap { event in
            guard !event.isAllDay else { return nil }
            guard !discardedIds.contains(event.eventIdentifier) else { return nil }
            guard !exportedIds.contains(event.eventIdentifier) else { return nil }

            return CalendarSlot(
                id: event.eventIdentifier,
                title: event.title ?? "Event",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay
            )
        }
    }

    // MARK: - Export

    /// Export plan slots as EKEvents to the user's default calendar.
    func exportPlan(_ slots: [AgendaSlot], city: String) throws -> [String: String] {
        guard hasAccess else { return [:] }

        let calendar = calendarService.defaultCalendar
        var mapping: [String: String] = [:]

        for slot in slots {
            if slot.source == .calendar { continue }

            // If previously exported, delete old event
            if let existingEventId = store.exportedEventId(for: slot.id) {
                try? calendarService.deleteEvent(id: existingEventId)
            }

            let event = EKEvent(eventStore: calendarService.store)
            event.title = slot.venueName
            event.startDate = slot.slotDate
            event.endDate = slot.scheduledEndDate
            event.notes = slot.reason
            event.calendar = calendar
            event.location = "\(slot.venueName), \(city)"

            if let lat = slot.lat, let lon = slot.lon {
                let structuredLocation = EKStructuredLocation(title: slot.venueName)
                structuredLocation.geoLocation = CLLocation(latitude: lat, longitude: lon)
                event.structuredLocation = structuredLocation
            }

            let eventId = try calendarService.createEvent(event)
            store.storeExport(slotId: slot.id, eventId: eventId)
            mapping[slot.id] = eventId
        }

        return mapping
    }

    // MARK: - Cleanup

    func removeExportedEvents(ids: [String]) {
        for eventId in ids {
            try? calendarService.deleteEvent(id: eventId)
        }
    }

    func clearExportStore() {
        let allExports = store.allExports()
        removeExportedEvents(ids: Array(allExports.values))
        store.clearExports()
    }

    // MARK: - Discard

    func discardEvent(id: String) {
        store.discard(eventId: id)
    }
}
