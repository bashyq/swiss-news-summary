import Foundation

/// How the check-in was triggered.
enum CheckInSource: String, Codable {
    case manual     // user tapped Done ✓
    case geofence   // CLLocationManager region entry
}

/// A single check-in event during agenda execution.
struct CheckInRecord: Codable, Identifiable {
    var id: String { "\(venueId)-\(date.timeIntervalSince1970)" }

    let venueId: String
    let venueName: String
    let scheduledTime: Date             // when the slot was originally scheduled to start
    let scheduledEndTime: Date          // when the slot was expected to end (start + duration)
    let actualDepartureTime: Date       // when the user actually tapped Done ✓
    let delta: TimeInterval             // positive = left late (ran over), negative = left early
    let source: CheckInSource
    let date: Date                      // calendar start-of-day
}
