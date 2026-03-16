import Foundation

// MARK: - Anchor Category

/// Classifies an anchor's purpose for gap suppression logic.
/// Food anchors suppress adjacent food slots; social/activity suppress adjacent activity slots.
enum AnchorCategory: String, Codable, CaseIterable {
    case food       // restaurant, brunch, café
    case social     // birthday party, playdate
    case activity   // sport, class, museum
    case errand     // shopping, appointment
    case other      // uncategorized

    var emoji: String {
        switch self {
        case .food:     return "🍴"
        case .social:   return "🎉"
        case .activity: return "🏃"
        case .errand:   return "🛒"
        case .other:    return "📌"
        }
    }

    var displayName: String {
        switch self {
        case .food:     return "Food"
        case .social:   return "Social"
        case .activity: return "Activity"
        case .errand:   return "Errand"
        case .other:    return "Other"
        }
    }

    var displayNameDE: String {
        switch self {
        case .food:     return "Essen"
        case .social:   return "Sozial"
        case .activity: return "Aktivität"
        case .errand:   return "Besorgung"
        case .other:    return "Anderes"
        }
    }
}

// MARK: - Anchor Event

/// A pre-existing commitment the user adds before agenda composition.
/// Anchors are treated as immovable locked slots — the AI builds around them.
/// Replaces the previous `DayAnchor` model (v5).
struct AnchorEvent: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var category: AnchorCategory
    var startTime: Date
    var durationMinutes: Int
    var neighbourhood: String?
    var kreis: Int?
    var sourceEventId: String?
    let createdDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        category: AnchorCategory,
        startTime: Date,
        durationMinutes: Int,
        neighbourhood: String? = nil,
        kreis: Int? = nil,
        sourceEventId: String? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.neighbourhood = neighbourhood
        self.kreis = kreis
        self.sourceEventId = sourceEventId
        self.createdDate = createdDate
    }

    var endTime: Date {
        startTime.addingTimeInterval(Double(durationMinutes) * 60)
    }

    /// Formatted time string (HH:mm) for display and prompt injection.
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return formatter.string(from: startTime)
    }

    /// Description sent to Claude in the agenda prompt.
    var promptDescription: String {
        var parts = [
            "\"\(title)\"",
            "category: \(category.rawValue)",
            "starts: \(startTime.formatted(.dateTime.hour().minute()))",
            "ends: \(endTime.formatted(.dateTime.hour().minute()))"
        ]
        if let n = neighbourhood { parts.append("location: \(n)") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Legacy Alias

/// Backward-compatible alias. Existing views reference `DayAnchor`; they will
/// be migrated to `AnchorEvent` in the UI pass (Step 10+).
typealias DayAnchor = AnchorEvent
