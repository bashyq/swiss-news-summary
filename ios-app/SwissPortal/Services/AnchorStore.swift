import Foundation

/// UserDefaults-backed store for anchor commitments, keyed by date.
///
/// Today's anchors use the legacy `"znuni.dayAnchors"` key for backward compatibility.
/// Weekend (and future) days use date-keyed storage: `"znuni.anchors.yyyy-MM-dd"`.
/// `purgeStaleKeys()` removes keys older than 7 days.
final class AnchorStore {
    static let shared = AnchorStore()

    /// Posted on every mutation so any tab can react (e.g. TodayViewModel rebuilds the agenda).
    static let didChangeNotification = Notification.Name("znuni.anchorDidChange")

    private let legacyKey = "znuni.dayAnchors"
    private static let keyPrefix = "znuni.anchors."
    private let defaults = UserDefaults.standard

    // MARK: - Date Key

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f
    }()

    private static func dateKey(_ date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    // MARK: - Read

    /// All anchors for today (legacy path — reads from legacy key).
    func anchors() -> [AnchorEvent] {
        guard let data = defaults.data(forKey: legacyKey),
              let list = try? JSONDecoder().decode([AnchorEvent].self, from: data) else {
            return []
        }
        return list.sorted { $0.startTime < $1.startTime }
    }

    /// Anchors for a specific date.
    /// Today reads from the legacy key; other dates use date-keyed storage.
    func anchors(for date: Date) -> [AnchorEvent] {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return anchors()
        }
        let key = Self.keyPrefix + Self.dateKey(date)
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([AnchorEvent].self, from: data) else {
            return []
        }
        return list.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Write (today — legacy)

    /// Add a new anchor for today (max 5).
    func add(_ anchor: AnchorEvent) {
        var list = anchors()
        guard list.count < 5 else { return }
        list.append(anchor)
        save(list)
    }

    /// Update an existing anchor for today.
    func update(_ anchor: AnchorEvent) {
        var list = anchors()
        guard let index = list.firstIndex(where: { $0.id == anchor.id }) else { return }
        list[index] = anchor
        save(list)
    }

    /// Remove an anchor by ID from today's list.
    func remove(id: UUID) {
        var list = anchors()
        list.removeAll { $0.id == id }
        save(list)
    }

    // MARK: - Write (date-keyed)

    /// Add an anchor for a specific date (max 5 per day).
    func add(_ anchor: AnchorEvent, for date: Date) {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            add(anchor)
            return
        }
        var list = anchors(for: date)
        guard list.count < 5 else { return }
        list.append(anchor)
        saveDateKeyed(list, for: date)
    }

    /// Remove an anchor by ID from a specific date.
    func remove(id: UUID, for date: Date) {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            remove(id: id)
            return
        }
        var list = anchors(for: date)
        list.removeAll { $0.id == id }
        saveDateKeyed(list, for: date)
    }

    // MARK: - Purge

    /// Remove all anchors from previous days (legacy key only).
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

    /// Remove date-keyed entries older than 7 days.
    /// Call alongside `purgeIfNewDay()`.
    func purgeStaleKeys() {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date())!
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(Self.keyPrefix) {
            let dateStr = String(key.dropFirst(Self.keyPrefix.count))
            if let date = Self.dateKeyFormatter.date(from: dateStr), date < cutoff {
                defaults.removeObject(forKey: key)
            }
        }
    }

    /// Clear all anchors (today only — legacy key).
    func clearAll() {
        defaults.removeObject(forKey: legacyKey)
    }

    // MARK: - Private

    private func save(_ list: [AnchorEvent]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: legacyKey)
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func saveDateKeyed(_ list: [AnchorEvent], for date: Date) {
        let key = Self.keyPrefix + Self.dateKey(date)
        if list.isEmpty {
            defaults.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
