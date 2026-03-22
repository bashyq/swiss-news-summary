import EventKit

/// Singleton wrapper around EKEventStore for calendar read/write operations.
/// Request access on first use only — never on app launch.
final class CalendarService {
    static let shared = CalendarService()
    let store = EKEventStore()

    private init() {}

    // MARK: - Permission

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Request full calendar access (iOS 17+).
    /// Returns true if granted, false otherwise.
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            if granted {
                // EKEventStore requires a reset after first access grant
                // to actually receive event data (Apple docs requirement).
                store.reset()
            }
            return granted
        } catch {
            #if DEBUG
            print("📅 Calendar access error: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Read

    /// Fetch events for a specific date (includes both timed and all-day events).
    func fetchEvents(for date: Date) -> [EKEvent] {
        // Pull latest data from remote sources (iCloud, Exchange, etc.)
        store.refreshSourcesIfNecessary()

        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        #if DEBUG
        print("📅 CalendarService.fetchEvents: date=\(date), start=\(start), end=\(end)")
        print("📅 CalendarService.fetchEvents: found \(events.count) total events (\(events.filter { $0.isAllDay }.count) all-day)")
        for event in events {
            print("   → \"\(event.title ?? "?")\" allDay=\(event.isAllDay) start=\(event.startDate ?? start) end=\(event.endDate ?? end)")
        }
        #endif

        return events
    }

    // MARK: - Write

    /// Create a new calendar event and return its eventIdentifier.
    func createEvent(_ event: EKEvent) throws -> String {
        try store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    /// Update an existing calendar event by ID.
    func updateEvent(id: String, title: String, startDate: Date, endDate: Date, notes: String?) throws {
        guard let event = store.event(withIdentifier: id) else { return }
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        try store.save(event, span: .thisEvent)
    }

    /// Delete a calendar event by ID.
    func deleteEvent(id: String) throws {
        guard let event = store.event(withIdentifier: id) else { return }
        try store.remove(event, span: .thisEvent)
    }

    // MARK: - Calendar Picker

    /// The user's default calendar for new events.
    var defaultCalendar: EKCalendar? {
        store.defaultCalendarForNewEvents
    }

    /// All writable calendars the user can pick from in Settings.
    func allCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }
}
