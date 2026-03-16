import Foundation

/// Persists the IDs of calendar events the user has explicitly discarded.
/// Discarded events never resurface in the swipe screen.
final class CalendarDiscardStore {
    static let shared = CalendarDiscardStore()
    private let key = "znuni.discardedCalendarEventIds"

    private init() {}

    /// Mark a calendar event as discarded.
    func discard(_ eventId: String) {
        var ids = all()
        ids.insert(eventId)
        save(ids)
    }

    /// Check if a calendar event was previously discarded.
    func isDiscarded(_ eventId: String) -> Bool {
        all().contains(eventId)
    }

    /// All discarded event IDs.
    func all() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(array)
    }

    /// Clear all discarded events (used in Settings).
    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func save(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: key)
    }
}
