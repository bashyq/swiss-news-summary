import Foundation

/// UserDefaults-backed store for today's anchor commitments.
/// Anchors never persist beyond their creation day — `purgeIfNewDay()` removes stale entries.
final class AnchorStore {
    static let shared = AnchorStore()

    private let key = "znuni.dayAnchors"
    private let defaults = UserDefaults.standard

    /// All current anchors, sorted by time.
    func anchors() -> [DayAnchor] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([DayAnchor].self, from: data) else {
            return []
        }
        return list.sorted { $0.time < $1.time }
    }

    /// Add a new anchor (max 3).
    func add(_ anchor: DayAnchor) {
        var list = anchors()
        guard list.count < 3 else { return }
        list.append(anchor)
        save(list)
    }

    /// Update an existing anchor.
    func update(_ anchor: DayAnchor) {
        var list = anchors()
        guard let index = list.firstIndex(where: { $0.id == anchor.id }) else { return }
        list[index] = anchor
        save(list)
    }

    /// Remove an anchor by ID.
    func remove(id: UUID) {
        var list = anchors()
        list.removeAll { $0.id == id }
        save(list)
    }

    /// Remove all anchors from previous days.
    /// Call from `TodayView.onAppear` and `ScenePhase.active`.
    func purgeIfNewDay() {
        let calendar = Calendar.current
        let today = Date()
        var list = anchors()
        let before = list.count
        list.removeAll { !calendar.isDate($0.createdDate, inSameDayAs: today) }
        if list.count != before {
            save(list)
        }
    }

    /// Clear all anchors.
    func clearAll() {
        defaults.removeObject(forKey: key)
    }

    private func save(_ list: [DayAnchor]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
    }
}
