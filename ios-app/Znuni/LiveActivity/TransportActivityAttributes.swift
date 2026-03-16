import ActivityKit
import Foundation

/// ActivityAttributes defining the data model for transport disruption Live Activities.
struct TransportActivityAttributes: ActivityAttributes {

    /// Static context — set when the activity starts, doesn't change.
    var cityName: String

    /// Dynamic state — updated each time we refresh transport data.
    struct ContentState: Codable, Hashable {
        /// Number of currently delayed departures
        var totalDelayed: Int
        /// Maximum delay in minutes
        var maxDelay: Int
        /// Status level: "none", "minor", "major"
        var status: String
        /// Top delays to display (max 3)
        var topDelays: [LiveDelay]
    }
}

/// Lightweight delay entry for the Live Activity content state.
struct LiveDelay: Codable, Hashable, Identifiable {
    let line: String
    let destination: String
    let delay: Int
    let scheduledTime: String

    var id: String { "\(line)-\(scheduledTime)" }
}
