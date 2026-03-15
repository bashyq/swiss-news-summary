import Foundation

/// Tracks venue IDs shown in agendas to avoid repetition.
/// Entries expire after 14 days.
final class RecentlyShownStore {
    static let shared = RecentlyShownStore()

    private let key = "znuni.recentlyShown"
    private let expiryDays = 14

    private struct Entry: Codable {
        let venueId: String
        let shownAt: Date
    }

    // MARK: - Public API

    /// Record that a venue was shown in today's agenda.
    func recordShown(venueId: String) {
        var entries = loadEntries()
        // Remove existing entry for this venue (will re-add with fresh date)
        entries.removeAll { $0.venueId == venueId }
        entries.append(Entry(venueId: venueId, shownAt: Date()))
        // Prune expired while we're at it
        let cutoff = Calendar.current.date(byAdding: .day, value: -expiryDays, to: Date()) ?? Date()
        entries.removeAll { $0.shownAt < cutoff }
        saveEntries(entries)
    }

    /// IDs of venues shown within the last 14 days.
    func recentlyShownIds() -> Set<String> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -expiryDays, to: Date()) ?? Date()
        let entries = loadEntries().filter { $0.shownAt >= cutoff }
        return Set(entries.map(\.venueId))
    }

    /// Clear all entries (for testing).
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private

    private func loadEntries() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveEntries(_ entries: [Entry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
