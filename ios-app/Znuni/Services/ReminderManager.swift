import Foundation
import UserNotifications

/// Manages activity reminders using local notifications.
@Observable
final class ReminderManager {
    /// All stored reminders
    var reminders: [ActivityReminder] = []

    private let storageKey = "activityReminders"

    init() {
        loadReminders()
    }

    // MARK: - Public API

    /// Schedule a reminder for an activity on a given date at 9:00 AM
    func scheduleReminder(activityId: String, name: String, date: Date) async {
        let granted = await requestPermission()
        guard granted else { return }

        let notificationId = "reminder-\(activityId)-\(Int(date.timeIntervalSince1970))"

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Activity Reminder"
        content.body = name
        content.sound = .default

        // Schedule at 9:00 AM on the chosen date
        var calendar = Calendar.current
        calendar.timeZone = .current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)

            let reminder = ActivityReminder(
                activityId: activityId,
                name: name,
                date: date,
                notificationId: notificationId
            )

            await MainActor.run {
                reminders.append(reminder)
                saveReminders()
            }
        } catch {
            // Notification scheduling failed — silently ignore
        }
    }

    /// Remove a reminder for a specific activity
    func removeReminder(for activityId: String) {
        let toRemove = reminders.filter { $0.activityId == activityId }
        let ids = toRemove.map(\.notificationId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        reminders.removeAll { $0.activityId == activityId }
        saveReminders()
    }

    /// Check if an activity has a pending reminder
    func hasReminder(for activityId: String) -> Bool {
        reminders.contains { $0.activityId == activityId }
    }

    /// Reminder date for an activity (if set)
    func reminderDate(for activityId: String) -> Date? {
        reminders.first { $0.activityId == activityId }?.date
    }

    /// Clean up past reminders (call on app launch)
    func cleanupPastReminders() {
        let now = Date()
        let expired = reminders.filter { $0.date < now }
        let ids = expired.map(\.notificationId)
        if !ids.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        reminders.removeAll { $0.date < now }
        saveReminders()
    }

    // MARK: - Permission

    private func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    // MARK: - Persistence

    private func loadReminders() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ActivityReminder].self, from: data) else {
            return
        }
        reminders = decoded
    }

    private func saveReminders() {
        if let encoded = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

// MARK: - Model

struct ActivityReminder: Codable, Identifiable {
    let activityId: String
    let name: String
    let date: Date
    let notificationId: String

    var id: String { notificationId }
}
