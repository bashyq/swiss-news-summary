import Foundation
import UserNotifications

/// Schedules local notifications for agenda execution:
/// - "Leave now" nudges before each slot transition
/// - Fallback check-in prompts 30 min after scheduled slot start
final class AgendaNotificationScheduler {
    static let shared = AgendaNotificationScheduler()

    private init() {}

    /// Schedule all notifications for the given slots.
    /// Cancels any existing agenda notifications first.
    func schedule(for slots: [AgendaSlot]) {
        let center = UNUserNotificationCenter.current()

        // Cancel existing agenda notifications
        let ids = slots.flatMap { slot in
            ["leave_\(slot.id)", "checkin_prompt_\(slot.id)"]
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        for i in 0..<slots.count {
            let slot = slots[i]

            // "Leave now" notification — fires travelMinutes + 5 min before next slot
            if let travelMins = slot.travelToNext?.minutes, i + 1 < slots.count {
                let nextSlot = slots[i + 1]
                let leaveAt = nextSlot.slotDate.addingTimeInterval(
                    Double(-travelMins - 5) * 60
                )
                // Only schedule if in the future
                if leaveAt > Date() {
                    scheduleLeaveNotification(
                        slotId: slot.id,
                        venue: slot.venueName,
                        nextVenue: nextSlot.venueName,
                        travelMins: travelMins,
                        fireAt: leaveAt
                    )
                }
            }

            // Fallback check-in prompt — 30 min after scheduled start
            let promptAt = slot.slotDate.addingTimeInterval(30 * 60)
            if promptAt > Date() && slot.checkOutTime == nil {
                scheduleCheckInPrompt(
                    slotId: slot.id,
                    venue: slot.venueName,
                    fireAt: promptAt
                )
            }
        }
    }

    /// Cancel and re-schedule after a timeline shift.
    func reschedule(for slots: [AgendaSlot]) {
        schedule(for: slots)
    }

    /// Cancel all agenda notifications.
    func cancelAll(for slots: [AgendaSlot]) {
        let ids = slots.flatMap { slot in
            ["leave_\(slot.id)", "checkin_prompt_\(slot.id)"]
        }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Permission

    /// Request notification permission. Returns true if granted.
    @discardableResult
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Check current authorization status.
    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Private

    private func scheduleLeaveNotification(
        slotId: String, venue: String,
        nextVenue: String, travelMins: Int, fireAt: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Time to leave for \(nextVenue)"
        content.body = "\(travelMins) min journey — head off now"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireAt
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components, repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "leave_\(slotId)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleCheckInPrompt(
        slotId: String, venue: String, fireAt: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "At \(venue)?"
        content.body = "Tap to check in and keep your day on track"
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireAt
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components, repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "checkin_prompt_\(slotId)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
