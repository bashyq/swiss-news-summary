import Foundation

// MARK: - Analytics Events

/// All analytics events for Znuni, using `Analytics.signal()` wrapper.
/// Naming convention: `{flow}.{action}` — dot-separated, lowercase.
enum ZnuniEvent {

    // MARK: - Tab Navigation (Q5)

    static func tabSwitched(to tab: String) {
        Analytics.signal("tab.switched", parameters: ["tab": tab])
    }

    // MARK: - Plan Flow (Q1)

    static func planGenerated(source: String, city: String, slotCount: Int, badWeather: Bool) {
        Analytics.signal("plan.generated", parameters: [
            "source": source,
            "city": city,
            "slotCount": "\(slotCount)",
            "badWeather": "\(badWeather)"
        ])
    }

    // MARK: - Plan Interaction (Q2)

    static func planSlotSwapped(slotType: String) {
        Analytics.signal("plan.slot.swapped", parameters: ["slotType": slotType])
    }

    static func planSlotSuggestAnother() {
        Analytics.signal("plan.slot.suggestAnother")
    }

    static func planRebuilt() {
        Analytics.signal("plan.rebuilt")
    }

    static func planSlotEdited(action: String) {
        Analytics.signal("plan.slot.edited", parameters: ["action": action])
    }

    // MARK: - Execution (Q3)

    static func planLetsGo() {
        Analytics.signal("plan.letsGo")
    }

    static func executionSlotDone(slotType: String, minutesDelta: Int) {
        Analytics.signal("execution.slot.done", parameters: [
            "slotType": slotType,
            "minutesDelta": "\(minutesDelta)"
        ])
    }

    static func executionGetDirections(slotType: String) {
        Analytics.signal("execution.getDirections", parameters: ["slotType": slotType])
    }

    // MARK: - Sharing (Q4)

    static func planShared(method: String) {
        Analytics.signal("plan.shared", parameters: ["method": method])
    }

    // MARK: - Session (Q6)

    static func sessionChanged(childCount: Int, soloParent: Bool) {
        Analytics.signal("session.changed", parameters: [
            "childCount": "\(childCount)",
            "soloParent": "\(soloParent)"
        ])
    }

    // MARK: - Discover Flow (Q7/Q8)

    static func discoverNudgeTapped(type: String) {
        Analytics.signal("discover.nudge.tapped", parameters: ["type": type])
    }

    static func discoverSunshineOpened() {
        Analytics.signal("discover.sunshine.opened")
    }

    static func discoverSnowOpened() {
        Analytics.signal("discover.snow.opened")
    }

    static func discoverCategoryTapped(category: String) {
        Analytics.signal("discover.category.tapped", parameters: ["category": category])
    }

    static func discoverPlanThis(source: String) {
        Analytics.signal("discover.planThis", parameters: ["source": source])
    }

    // MARK: - Errors

    static func apiError(endpoint: String, error: String) {
        Analytics.signal("error.api", parameters: [
            "endpoint": endpoint,
            "error": error
        ])
    }
}
