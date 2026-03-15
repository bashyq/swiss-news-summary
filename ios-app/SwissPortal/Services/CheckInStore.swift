import Foundation

/// UserDefaults-backed store for check-in records with 90-day retention.
final class CheckInStore {
    static let shared = CheckInStore()

    private let key = "znuni.checkIns"
    private let maxAgeDays = 90

    private init() {}

    // MARK: - Record

    /// Record a new check-in and purge entries older than 90 days.
    func record(_ checkIn: CheckInRecord) {
        var records = allRecords()
        records.append(checkIn)
        purgeOldEntries(&records)
        save(records)
    }

    // MARK: - Query

    /// All stored records (newest first).
    func allRecords() -> [CheckInRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([CheckInRecord].self, from: data)
        else { return [] }
        return records
    }

    /// Records from the last N days.
    func recentRecords(days: Int = 14) -> [CheckInRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return allRecords().filter { $0.date >= cutoff }
    }

    /// Records from today only.
    func todayRecords() -> [CheckInRecord] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allRecords().filter { $0.date >= startOfDay }
    }

    // MARK: - Flush to RecentlyShown

    /// At end of day, mark all checked-in venue IDs as recently shown.
    func flushToRecentlyShown(_ store: RecentlyShownStore) {
        let todayIds = Set(todayRecords().map { $0.venueId })
        for id in todayIds {
            store.recordShown(venueId: id)
        }
    }

    // MARK: - Average Delta (seed for Concept 3)

    /// Average check-in delta for a given hour slot across recent records.
    /// Returns nil if fewer than 3 data points.
    func averageDelta(forHour hour: Int) -> TimeInterval? {
        let relevant = recentRecords(days: 90).filter {
            Calendar.current.component(.hour, from: $0.scheduledTime) == hour
        }
        guard relevant.count >= 3 else { return nil }
        let total = relevant.reduce(0.0) { $0 + $1.delta }
        return total / Double(relevant.count)
    }

    // MARK: - Private

    private func purgeOldEntries(_ records: inout [CheckInRecord]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: Date()) ?? Date()
        records.removeAll { $0.date < cutoff }
    }

    private func save(_ records: [CheckInRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
