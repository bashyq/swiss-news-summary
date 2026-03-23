import Foundation

/// Warning produced after a timeline shift, indicating a potential problem.
struct FeasibilityWarning: Identifiable {
    var id: String { slotId + "-" + type.rawValue }

    let slotId: String
    let type: WarningType
    let message: String
    let suggestedResolution: Resolution?

    enum WarningType: String {
        case dinnerTooLate              // dinner shifted past 20:00
        case venueClosedAtShiftedTime   // venue likely closed at new time
        case activityDurationSqueezed   // < 30 min before next slot
    }

    enum Resolution: Equatable {
        case skipSlot(slotId: String)
        case shortenSlot(slotId: String)
    }

    /// Priority for display — lower is more critical.
    var priority: Int {
        switch type {
        case .dinnerTooLate: return 0
        case .venueClosedAtShiftedTime: return 1
        case .activityDurationSqueezed: return 2
        }
    }
}

/// Checks shifted slot times for feasibility problems.
///
/// Runs after timeline shifts. Returns warnings sorted by priority
/// (most critical first). Only one banner is shown at a time.
struct FeasibilityChecker {

    /// Check all slots for feasibility issues after a timeline shift.
    static func check(slots: [AgendaSlot]) -> [FeasibilityWarning] {
        var warnings: [FeasibilityWarning] = []

        for (index, slot) in slots.enumerated() {
            let slotDate = slot.slotDate
            let hour = Calendar.current.component(.hour, from: slotDate)
            let minute = Calendar.current.component(.minute, from: slotDate)
            let totalMinutes = hour * 60 + minute

            // 1. Dinner too late — dinner slot shifted past 20:00
            if slot.type == .dinner && totalMinutes > 20 * 60 {
                let timeStr = slot.time
                let prevSlotId = index > 0 ? slots[index - 1].id : slot.id
                warnings.append(FeasibilityWarning(
                    slotId: slot.id,
                    type: .dinnerTooLate,
                    message: "Dinner now at \(timeStr) — skip \(index > 0 ? slots[index - 1].venueName : "previous stop") and head straight to \(slot.venueName)?",
                    suggestedResolution: index > 0 ? .skipSlot(slotId: prevSlotId) : nil
                ))
            }

            // 2. Activity duration squeezed — less than 30 min gap between end of this slot and start of next
            if index < slots.count - 1 {
                let nextSlot = slots[index + 1]
                let nextDate = nextSlot.slotDate
                let gapMinutes = nextDate.timeIntervalSince(slot.scheduledEndDate) / 60

                // Account for travel time
                let travelMins = Double(slot.travelToNext?.minutes ?? 0)
                let usableMinutes = gapMinutes - travelMins

                if usableMinutes < 0 {
                    // Overlap — next slot starts before this one ends + travel
                    warnings.append(FeasibilityWarning(
                        slotId: slot.id,
                        type: .activityDurationSqueezed,
                        message: "Not enough time at \(slot.venueName) before heading to \(nextSlot.venueName). Skip it?",
                        suggestedResolution: .skipSlot(slotId: slot.id)
                    ))
                } else if usableMinutes < 30 {
                    warnings.append(FeasibilityWarning(
                        slotId: slot.id,
                        type: .activityDurationSqueezed,
                        message: "Only \(Int(usableMinutes)) min at \(slot.venueName) before heading to \(nextSlot.venueName). Skip it?",
                        suggestedResolution: .skipSlot(slotId: slot.id)
                    ))
                }
            }
        }

        // Sort by priority (most critical first)
        return warnings.sorted { $0.priority < $1.priority }
    }
}
