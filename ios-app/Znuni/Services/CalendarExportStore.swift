import Foundation

/// Tracks which EKEvent IDs were created by Znüni for each plan slot,
/// so they can be updated on slot swap or deleted on plan rebuild.
final class CalendarExportStore {
    static let shared = CalendarExportStore()
    private let key = "znuni.calendarExportMap"

    private init() {}

    /// Store an exported event ID for a slot.
    func store(slotId: String, eventId: String) {
        var map = all()
        map[slotId] = eventId
        save(map)
    }

    /// Get the exported event ID for a slot.
    func eventId(for slotId: String) -> String? {
        all()[slotId]
    }

    /// All slot → event mappings.
    func all() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    /// Clear all exported event mappings.
    func removeAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Whether any plan slots have been exported to calendar.
    var hasExportedPlan: Bool {
        !all().isEmpty
    }

    private func save(_ map: [String: String]) {
        UserDefaults.standard.set(map, forKey: key)
    }
}
