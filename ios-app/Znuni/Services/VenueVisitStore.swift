import Foundation

/// UserDefaults-backed store for venue visit history with 90-day retention.
/// Used by `FreshnessScorer` to determine venue eligibility and scoring.
class VenueVisitStore {
    static let shared = VenueVisitStore()

    let profileId = "bisho"

    private let key = "znuni.venueVisits"
    private let maxAgeDays = 90

    init() {}

    // MARK: - Record

    /// Record a new visit and purge entries older than 90 days.
    func record(_ visit: VenueVisit) {
        var visits = allVisits()
        visits.append(visit)
        purgeOldEntries(&visits)
        save(visits)
    }

    /// Convenience: record a visit for a venue ID with minimal parameters.
    func recordVisit(
        venueId: String,
        venueName: String,
        venueType: VenueType,
        source: VisitSource,
        weatherCondition: String? = nil,
        familySnapshot: String = ""
    ) {
        let visit = VenueVisit(
            profileId: profileId,
            venueId: venueId,
            venueName: venueName,
            venueType: venueType,
            source: source,
            weatherCondition: weatherCondition,
            familySnapshot: familySnapshot
        )
        record(visit)
    }

    // MARK: - Query

    /// All stored visits (newest first).
    func allVisits() -> [VenueVisit] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let visits = try? JSONDecoder().decode([VenueVisit].self, from: data)
        else { return [] }
        return visits.sorted { $0.visitDate > $1.visitDate }
    }

    /// Most recent visit for a given venue.
    func lastVisit(for venueId: String) -> VenueVisit? {
        allVisits().first { $0.venueId == venueId }
    }

    /// Days since the most recent visit to a venue. Returns nil if never visited.
    func daysSinceLastVisit(for venueId: String) -> Int? {
        guard let visit = lastVisit(for: venueId) else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: visit.visitDate, to: Date()).day
    }

    /// Number of visits to a venue in the last N days.
    func visitCount(for venueId: String, inLast days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return allVisits().filter { $0.venueId == venueId && $0.visitDate >= cutoff }.count
    }

    /// All venue IDs visited in the last N days.
    func recentlyVisitedIds(days: Int = 14) -> Set<String> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let visits = allVisits().filter { $0.visitDate >= cutoff }
        return Set(visits.map(\.venueId))
    }

    /// Clear all visits (for testing).
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private

    private func purgeOldEntries(_ visits: inout [VenueVisit]) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: Date()) ?? Date()
        visits.removeAll { $0.visitDate < cutoff }
    }

    private func save(_ visits: [VenueVisit]) {
        if let data = try? JSONEncoder().encode(visits) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
