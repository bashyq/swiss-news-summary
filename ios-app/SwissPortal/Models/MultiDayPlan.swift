import Foundation

// MARK: - Planned Day

/// A single day within a multi-day plan.
/// Contains anchors for that day and the composed agenda (if any).
struct PlannedDay: Codable, Identifiable {
    let id: UUID
    let date: Date
    var anchors: [AnchorEvent]
    var agenda: DayAgenda?

    /// Whether the agenda has been composed for this day.
    var isComposed: Bool { agenda != nil }

    /// ISO date string for this day.
    var isoDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f.string(from: date)
    }

    init(
        id: UUID = UUID(),
        date: Date,
        anchors: [AnchorEvent] = [],
        agenda: DayAgenda? = nil
    ) {
        self.id = id
        self.date = date
        self.anchors = anchors
        self.agenda = agenda
    }
}

// MARK: - Multi-Day Plan

/// A multi-day plan (e.g. weekend plan) containing agendas for each day.
/// Persisted locally via `MultiDayPlanStore` and synced to KV in future.
struct MultiDayPlan: Codable, Identifiable {
    let id: UUID
    let title: String
    var days: [PlannedDay]
    let createdAt: Date

    /// All venue IDs used across all days.
    var allVenueIds: [String] {
        days.flatMap { $0.agenda?.slots.compactMap(\.venueId) ?? [] }
    }

    /// Find duplicate venue IDs that appear on more than one day.
    var crossDayDuplicates: Set<String> {
        var seen = Set<String>()
        var dupes = Set<String>()
        for day in days {
            let dayIds = Set(day.agenda?.slots.compactMap(\.venueId) ?? [])
            for id in dayIds {
                if seen.contains(id) {
                    dupes.insert(id)
                }
            }
            seen.formUnion(dayIds)
        }
        return dupes
    }

    init(
        id: UUID = UUID(),
        title: String,
        days: [PlannedDay],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.days = days
        self.createdAt = createdAt
    }

    /// Replace duplicate venues on day 2+ with their first swap option.
    /// Returns a new plan with duplicates resolved.
    func resolvingCrossDayDuplicates() -> MultiDayPlan {
        guard days.count > 1 else { return self }

        var result = self
        var usedIds = Set<String>()

        // Day 1's venue IDs are established
        if let firstDaySlots = result.days[0].agenda?.slots {
            usedIds = Set(firstDaySlots.compactMap(\.venueId))
        }

        // For subsequent days, replace duplicates with first swap
        for dayIndex in 1..<result.days.count {
            guard var agenda = result.days[dayIndex].agenda else { continue }
            for slotIndex in 0..<agenda.slots.count {
                guard let venueId = agenda.slots[slotIndex].venueId,
                      usedIds.contains(venueId) else { continue }

                // Try to replace with first swap that isn't also a duplicate
                if let swap = agenda.slots[slotIndex].swaps.first(where: {
                    guard let swapId = $0.venueId else { return false }
                    return !usedIds.contains(swapId)
                }) {
                    agenda.slots[slotIndex].venueName = swap.venueName
                    agenda.slots[slotIndex].venueId = swap.venueId
                    agenda.slots[slotIndex].reason = swap.detail
                }
            }

            // Add this day's final venue IDs to the used set
            let dayIds = Set(agenda.slots.compactMap(\.venueId))
            usedIds.formUnion(dayIds)
            result.days[dayIndex].agenda = agenda
        }

        return result
    }
}
