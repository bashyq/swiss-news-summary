import Foundation
import os.log

private let storeLog = Logger(subsystem: "Bashar.Znuni", category: "PlanStore")

/// Local plan store: in-memory cache with write-through JSON disk persistence.
/// Calendar discards and exports stored in UserDefaults (matching existing keys for migration).
@Observable
final class LocalPlanStore: PlanStoreProvider {
    static let shared = LocalPlanStore()

    // MARK: - In-Memory Cache

    private var plans: [String: DayAgenda] = [:]

    // MARK: - Disk Persistence

    private let storeDir: URL

    // MARK: - UserDefaults Keys (same as old stores — automatic migration)

    private let discardKey = "znuni.discardedCalendarEventIds"
    private let exportKey = "znuni.calendarExportMap"

    // MARK: - Init

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storeDir = docs.appendingPathComponent("PlanStore", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
    }

    // MARK: - Key Helpers

    private func key(city: String, date: String) -> String {
        "\(city)-\(date)"
    }

    private func fileURL(city: String, date: String) -> URL {
        storeDir.appendingPathComponent("\(key(city: city, date: date)).json")
    }

    // MARK: - Plans

    func loadPlan(city: String, date: String) -> DayAgenda? {
        let k = key(city: city, date: date)
        // Memory first
        if let cached = plans[k] {
            storeLog.debug("Plan loaded from memory: \(k)")
            return cached
        }
        // Disk fallback
        let url = fileURL(city: city, date: date)
        guard let data = try? Data(contentsOf: url),
              let agenda = try? JSONDecoder().decode(DayAgenda.self, from: data) else {
            return nil
        }
        plans[k] = agenda
        storeLog.debug("Plan loaded from disk: \(k), \(agenda.slots.count) slots")
        return agenda
    }

    func savePlan(_ agenda: DayAgenda, city: String, date: String) {
        let k = key(city: city, date: date)
        plans[k] = agenda
        // Write-through to disk
        if let data = try? JSONEncoder().encode(agenda) {
            try? data.write(to: fileURL(city: city, date: date))
            storeLog.debug("Plan saved: \(k), \(agenda.slots.count) slots")
        }
    }

    func deletePlan(city: String, date: String) {
        let k = key(city: city, date: date)
        plans.removeValue(forKey: k)
        try? FileManager.default.removeItem(at: fileURL(city: city, date: date))
        storeLog.debug("Plan deleted: \(k)")
    }

    // MARK: - Calendar Discards

    private var discardedIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: discardKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: discardKey) }
    }

    func isDiscarded(eventId: String) -> Bool {
        let normalized = PlanStoreID.normalize(eventId)
        return discardedIds.contains(normalized)
    }

    func discard(eventId: String) {
        let normalized = PlanStoreID.normalize(eventId)
        var ids = discardedIds
        ids.insert(normalized)
        discardedIds = ids
        storeLog.debug("Event discarded: \(normalized)")
    }

    func allDiscardedIds() -> Set<String> {
        discardedIds
    }

    func clearDiscards() {
        discardedIds = []
    }

    // MARK: - Calendar Exports

    private var exportMap: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: exportKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: exportKey) }
    }

    func exportedEventId(for slotId: String) -> String? {
        let normalized = PlanStoreID.normalize(slotId)
        return exportMap[normalized]
    }

    func storeExport(slotId: String, eventId: String) {
        let normalized = PlanStoreID.normalize(slotId)
        var map = exportMap
        map[normalized] = eventId
        exportMap = map
    }

    func allExports() -> [String: String] {
        exportMap
    }

    func clearExports() {
        exportMap = [:]
    }

    func hasExportedPlan() -> Bool {
        !exportMap.isEmpty
    }
}
