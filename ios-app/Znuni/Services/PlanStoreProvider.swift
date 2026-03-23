import Foundation

/// Protocol for plan persistence. Implementations can be local (disk/memory),
/// cloud (CloudKit), or custom backend. All IDs are normalized (no prefixes).
protocol PlanStoreProvider {
    // MARK: - Plans
    func loadPlan(city: String, date: String) -> DayAgenda?
    func savePlan(_ agenda: DayAgenda, city: String, date: String)
    func deletePlan(city: String, date: String)

    // MARK: - Calendar Discards
    func isDiscarded(eventId: String) -> Bool
    func discard(eventId: String)
    func allDiscardedIds() -> Set<String>
    func clearDiscards()

    // MARK: - Calendar Exports
    func exportedEventId(for slotId: String) -> String?
    func storeExport(slotId: String, eventId: String)
    func allExports() -> [String: String]
    func clearExports()
    func hasExportedPlan() -> Bool
}

// MARK: - ID Normalization (shared across all providers)

enum PlanStoreID {
    /// Strip "cal-" and "anchor-" prefixes to get raw identifiers.
    static func normalize(_ id: String) -> String {
        if id.hasPrefix("cal-") { return String(id.dropFirst(4)) }
        if id.hasPrefix("anchor-") { return String(id.dropFirst(7)) }
        return id
    }
}
