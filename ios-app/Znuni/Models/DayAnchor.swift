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

// MARK: - Anchor Source

/// Origin of an anchor event.
enum AnchorSource: String, Codable {
    case manual      // user entered via AnchorFormSheet
    case calendar    // imported from EventKit
    case cityEvent   // came from a Znüni CityEvent
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
    var source: AnchorSource
    var calendarEventId: String?
    let createdDate: Date
    var address: String?
    var lat: Double?
    var lon: Double?
    /// The original AgendaSlot ID, preserved so anchorToSlot can recreate with the same ID.
    var originalSlotId: String?

    /// Whether this anchor has a resolved geographic location.
    var hasLocation: Bool { lat != nil && lon != nil }

    enum CodingKeys: String, CodingKey {
        case id, title, category, startTime, durationMinutes
        case neighbourhood, kreis, sourceEventId
        case source, calendarEventId, createdDate
        case address, lat, lon, originalSlotId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(AnchorCategory.self, forKey: .category)
        startTime = try container.decode(Date.self, forKey: .startTime)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        neighbourhood = try container.decodeIfPresent(String.self, forKey: .neighbourhood)
        kreis = try container.decodeIfPresent(Int.self, forKey: .kreis)
        sourceEventId = try container.decodeIfPresent(String.self, forKey: .sourceEventId)
        source = try container.decodeIfPresent(AnchorSource.self, forKey: .source) ?? .manual
        calendarEventId = try container.decodeIfPresent(String.self, forKey: .calendarEventId)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
        originalSlotId = try container.decodeIfPresent(String.self, forKey: .originalSlotId)
    }

    init(
        id: UUID = UUID(),
        title: String,
        category: AnchorCategory,
        startTime: Date,
        durationMinutes: Int,
        neighbourhood: String? = nil,
        kreis: Int? = nil,
        sourceEventId: String? = nil,
        source: AnchorSource = .manual,
        calendarEventId: String? = nil,
        createdDate: Date = Date(),
        address: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        originalSlotId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.neighbourhood = neighbourhood
        self.kreis = kreis
        self.sourceEventId = sourceEventId
        self.source = source
        self.calendarEventId = calendarEventId
        self.createdDate = createdDate
        self.address = address
        self.lat = lat
        self.lon = lon
        self.originalSlotId = originalSlotId
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
        if let addr = address { parts.append("address: \(addr)") }
        if let lat, let lon { parts.append("coords: \(lat),\(lon)") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Legacy Alias

/// Backward-compatible alias. Existing views reference `DayAnchor`; they will
/// be migrated to `AnchorEvent` in the UI pass (Step 10+).
typealias DayAnchor = AnchorEvent
