import Foundation

/// A pre-existing commitment the user adds before agenda composition.
/// Anchors are treated as immovable locked slots — the AI builds around them.
struct DayAnchor: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String          // free text — "Birthday party", "Football match"
    var time: Date             // full Date with today's date + chosen time
    var neighbourhood: String? // optional — used for travel clustering
    var durationMinutes: Int?  // optional — used to determine what fits after
    let createdDate: Date      // date anchor was created — used for end-of-day purge

    init(
        id: UUID = UUID(),
        label: String,
        time: Date,
        neighbourhood: String? = nil,
        durationMinutes: Int? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.time = time
        self.neighbourhood = neighbourhood
        self.durationMinutes = durationMinutes
        self.createdDate = createdDate
    }

    /// Formatted time string (HH:mm) for display and prompt injection.
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return formatter.string(from: time)
    }

    /// Description sent to Claude in the agenda prompt.
    var promptDescription: String {
        var desc = "- \(label) at \(timeString)"
        if let hood = neighbourhood {
            desc += " in \(hood)"
        }
        if let dur = durationMinutes {
            desc += " (~\(dur) min)"
        }
        return desc
    }
}
