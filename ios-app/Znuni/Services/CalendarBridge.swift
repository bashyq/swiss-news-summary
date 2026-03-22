import EventKit
import CoreLocation

/// Unified calendar read/write/discard wrapper for the Plan tab.
/// Delegates to CalendarService, CalendarDiscardStore, and CalendarExportStore.
@Observable
final class CalendarBridge {

    // MARK: - Dependencies

    private let calendarService = CalendarService.shared
    private let discardStore = CalendarDiscardStore.shared
    private let exportStore = CalendarExportStore.shared

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
        let discardedIds = discardStore.all()
        let exportedIds = Set(exportStore.all().values)

        return ekEvents.compactMap { event in
            // Skip all-day events — they clutter the timeline
            guard !event.isAllDay else { return nil }
            // Skip events the user previously discarded
            guard !discardedIds.contains(event.eventIdentifier) else { return nil }
            // Skip events that Znuni itself exported (avoid duplicates)
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
    /// Returns a mapping of slotId → exported EKEvent identifier.
    func exportPlan(_ slots: [AgendaSlot], city: String) throws -> [String: String] {
        guard hasAccess else { return [:] }

        let calendar = calendarService.defaultCalendar
        var mapping: [String: String] = [:]

        for slot in slots {
            // Skip calendar-sourced slots — they already exist in the calendar
            if slot.source == .calendar { continue }

            // If this slot was previously exported, update it instead
            if let existingEventId = exportStore.eventId(for: slot.id) {
                try? calendarService.deleteEvent(id: existingEventId)
            }

            let event = EKEvent(eventStore: calendarService.store)
            event.title = slot.venueName
            event.startDate = slot.slotDate
            event.endDate = slot.scheduledEndDate
            event.notes = slot.reason
            event.calendar = calendar

            // Location string
            event.location = "\(slot.venueName), \(city)"

            // Structured location with coordinates if available
            if let lat = slot.lat, let lon = slot.lon {
                let structuredLocation = EKStructuredLocation(title: slot.venueName)
                structuredLocation.geoLocation = CLLocation(latitude: lat, longitude: lon)
                event.structuredLocation = structuredLocation
            }

            let eventId = try calendarService.createEvent(event)
            exportStore.store(slotId: slot.id, eventId: eventId)
            mapping[slot.id] = eventId
        }

        return mapping
    }

    // MARK: - Cleanup

    /// Remove previously exported EKEvents by their identifiers.
    /// Used when re-saving a plan or on plan rebuild.
    func removeExportedEvents(ids: [String]) {
        for eventId in ids {
            try? calendarService.deleteEvent(id: eventId)
        }
    }

    /// Clear all export tracking (e.g. on plan rebuild).
    func clearExportStore() {
        // Delete the actual calendar events first
        let allExports = exportStore.all()
        removeExportedEvents(ids: Array(allExports.values))
        exportStore.removeAll()
    }

    // MARK: - Discard

    /// Mark a calendar event as discarded so it won't appear in future fetches.
    func discardEvent(id: String) {
        discardStore.discard(id)
    }
}
