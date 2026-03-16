import ActivityKit
import Foundation

/// Manages the transport disruption Live Activity lifecycle.
///
/// Call `update(transport:cityName:)` after each news fetch. The manager
/// automatically starts, updates, or ends the Live Activity based on whether
/// delays exist.
///
/// Note: `ActivityKit.Activity` is fully qualified to avoid conflict with the
/// app's `Activity` model type.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: ActivityKit.Activity<TransportActivityAttributes>?

    private init() {}

    /// Update the Live Activity based on current transport data.
    ///
    /// - If delays exist and no activity is running → start one.
    /// - If delays exist and an activity is running → update it.
    /// - If no delays and an activity is running → end it.
    func update(transport: Transport, cityName: String) {
        let delays = transport.delays
        let summary = transport.summary

        if delays.isEmpty || summary.totalDelayed == 0 {
            endActivity()
            return
        }

        let topDelays = delays
            .sorted { $0.delay > $1.delay }
            .prefix(3)
            .map { LiveDelay(line: $0.line, destination: $0.destination, delay: $0.delay, scheduledTime: $0.scheduledTime) }

        let contentState = TransportActivityAttributes.ContentState(
            totalDelayed: summary.totalDelayed,
            maxDelay: summary.maxDelay,
            status: summary.status,
            topDelays: Array(topDelays)
        )

        if let activity = currentActivity {
            // Update existing activity
            Task {
                await activity.update(
                    ActivityContent(state: contentState, staleDate: Date().addingTimeInterval(30 * 60))
                )
            }
        } else {
            startActivity(cityName: cityName, contentState: contentState)
        }
    }

    // MARK: - Private

    private func startActivity(cityName: String, contentState: TransportActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TransportActivityAttributes(cityName: cityName)
        let content = ActivityContent(state: contentState, staleDate: Date().addingTimeInterval(30 * 60))

        do {
            currentActivity = try ActivityKit.Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("LiveActivity start failed: \(error)")
        }
    }

    private func endActivity() {
        guard let activity = currentActivity else { return }
        let finalState = TransportActivityAttributes.ContentState(
            totalDelayed: 0,
            maxDelay: 0,
            status: "none",
            topDelays: []
        )
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .default
            )
        }
        currentActivity = nil
    }
}
