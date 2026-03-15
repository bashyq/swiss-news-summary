import Foundation

/// Pure function that shifts downstream slot times when a check-in is early or late.
///
/// No side effects, no API calls — returns a new slot array.
struct TimelineShifter {

    /// Apply a uniform delta to all slots after `fromIndex`.
    ///
    /// - Parameters:
    ///   - slots: The current slot array.
    ///   - fromIndex: The index of the slot that was just checked in.
    ///   - delta: Time interval in seconds (positive = late, negative = early).
    /// - Returns: A new slot array with downstream times adjusted.
    static func shift(
        slots: [AgendaSlot],
        fromIndex: Int,
        delta: TimeInterval
    ) -> [AgendaSlot] {
        var result = slots

        for i in (fromIndex + 1)..<result.count {
            let originalDate = result[i].slotDate
            let shifted = originalDate.addingTimeInterval(delta)
            result[i].updateTime(from: shifted)
        }

        return result
    }

    /// Compute the delta between actual check-in time and scheduled slot time.
    /// Positive = late, negative = early.
    static func computeDelta(actualTime: Date, slot: AgendaSlot) -> TimeInterval {
        actualTime.timeIntervalSince(slot.slotDate)
    }
}
