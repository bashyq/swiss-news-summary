import Foundation

/// Deterministic gap classifier. Finds free time between anchors and assigns
/// a `SuggestionType` to each fillable gap. Runs entirely in Swift — no API calls.
///
/// Core principle: layout decisions (slot count, times, types) are made here.
/// Claude's only job is venue selection from a pre-qualified pool.
struct GapAnalysisEngine {
    static let dayStartHour = 8
    static let dayEndHour   = 21
    static let minFillableMinutes = 45

    /// Standard day-part windows used to subdivide open time.
    /// Each window maps to a suggestion type and an (hour, minute) range.
    private struct DaySlot {
        let type: SuggestionType
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
    }

    private static let standardSlots: [DaySlot] = [
        DaySlot(type: .morningActivity,   startHour:  8, startMinute:  0, endHour: 11, endMinute: 30),
        DaySlot(type: .lunch,             startHour: 11, startMinute: 30, endHour: 14, endMinute:  0),
        DaySlot(type: .afternoonActivity, startHour: 14, startMinute:  0, endHour: 17, endMinute: 30),
        DaySlot(type: .dinner,            startHour: 17, startMinute: 30, endHour: 21, endMinute:  0),
    ]

    /// Analyse a day's anchors and return the free gaps between them.
    ///
    /// - Parameters:
    ///   - anchors: The user's committed anchors for the day.
    ///   - now: Current time (for effective start calculation).
    ///   - date: The date being planned.
    /// - Returns: Array of `FreeGap`s, including non-fillable gaps for display.
    static func analyse(anchors: [AnchorEvent], now: Date, date: Date) -> [FreeGap] {
        let cal = Calendar.current
        guard let dayStart = cal.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: date),
              let dayEnd = cal.date(bySettingHour: dayEndHour, minute: 0, second: 0, of: date)
        else { return [] }

        let sorted = anchors.sorted { $0.startTime < $1.startTime }

        // Step 1: Find raw gaps between anchors (or day boundaries)
        var rawGaps: [(start: Date, end: Date, before: AnchorEvent?, after: AnchorEvent?)] = []
        var cursor = dayStart

        for (i, anchor) in sorted.enumerated() {
            if anchor.startTime > cursor {
                rawGaps.append((cursor, anchor.startTime,
                                i > 0 ? sorted[i - 1] : nil, anchor))
            }
            cursor = max(cursor, anchor.endTime)
        }
        if cursor < dayEnd {
            rawGaps.append((cursor, dayEnd, sorted.last, nil))
        }

        // Step 2: Subdivide each raw gap into standard day-part slots
        var results: [FreeGap] = []

        for raw in rawGaps {
            let suppressed = suppressedTypes(raw.before, raw.after)
            let effRawStart = max(raw.start, now.addingTimeInterval(15 * 60))

            // If raw gap is too short after applying now-offset, emit as non-fillable
            if effRawStart >= raw.end {
                results.append(FreeGap(
                    id: UUID(), gapStart: raw.start, gapEnd: raw.end,
                    effectiveStart: effRawStart,
                    effectiveMinutes: 0,
                    precedingAnchor: raw.before, followingAnchor: raw.after,
                    suggestedType: nil, isFillable: false
                ))
                continue
            }

            // Try to split into standard slots
            var slotResults: [FreeGap] = []

            for slot in standardSlots {
                guard let slotStart = cal.date(bySettingHour: slot.startHour, minute: slot.startMinute, second: 0, of: date),
                      let slotEnd = cal.date(bySettingHour: slot.endHour, minute: slot.endMinute, second: 0, of: date)
                else { continue }

                // Intersect with raw gap
                let overlapStart = max(raw.start, slotStart)
                let overlapEnd = min(raw.end, slotEnd)
                guard overlapStart < overlapEnd else { continue }

                // Apply now-offset
                let effStart = max(overlapStart, now.addingTimeInterval(15 * 60))
                let effMinutes = max(0, Int(overlapEnd.timeIntervalSince(effStart) / 60))

                guard effMinutes >= minFillableMinutes else { continue }
                guard !suppressed.contains(slot.type) else { continue }

                slotResults.append(FreeGap(
                    id: UUID(),
                    gapStart: overlapStart,
                    gapEnd: overlapEnd,
                    effectiveStart: effStart,
                    effectiveMinutes: effMinutes,
                    precedingAnchor: raw.before,
                    followingAnchor: raw.after,
                    suggestedType: slot.type,
                    isFillable: true
                ))
            }

            if slotResults.isEmpty {
                // No standard slot fit — emit the raw gap as non-fillable
                let effMinutes = max(0, Int(raw.end.timeIntervalSince(effRawStart) / 60))
                results.append(FreeGap(
                    id: UUID(), gapStart: raw.start, gapEnd: raw.end,
                    effectiveStart: effRawStart,
                    effectiveMinutes: effMinutes,
                    precedingAnchor: raw.before, followingAnchor: raw.after,
                    suggestedType: nil, isFillable: false
                ))
            } else {
                results.append(contentsOf: slotResults)
            }
        }

        return results
    }

    // MARK: - Suppression Logic

    /// Determine which suggestion types are suppressed by adjacent anchors.
    /// Food anchors suppress adjacent food slots; social/activity suppress activity slots.
    private static func suppressedTypes(
        _ pre: AnchorEvent?, _ fol: AnchorEvent?
    ) -> Set<SuggestionType> {
        var s = Set<SuggestionType>()

        if let pre = pre {
            let h = hour(pre.endTime)
            switch pre.category {
            case .food:
                if h >= 10 && h <= 15 { s.insert(.lunch) }
                if h >= 17 { s.insert(.dinner) }
            case .activity:
                // Only suppress the activity slot in the same time period as the anchor
                if h < 12 { s.insert(.morningActivity) }
                else { s.insert(.afternoonActivity) }
            case .social:
                s.insert(.afternoonActivity)
            default:
                break
            }
        }

        if let fol = fol {
            let h = hour(fol.startTime)
            switch fol.category {
            case .food:
                if h >= 11 && h <= 14 { s.insert(.lunch) }
                if h >= 17 { s.insert(.dinner) }
            default:
                break
            }
        }

        return s
    }

    private static func hour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}
