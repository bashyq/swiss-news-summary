import Foundation

/// Formats a `DayAgenda` into a clean text summary for sharing via iMessage/WhatsApp.
struct PlanShareFormatter {

    static func format(_ agenda: DayAgenda, city: String = "Zurich") -> String {
        var lines: [String] = []

        // Header
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, d MMMM"
        // Parse ISO date string to Date for formatting
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        isoFormatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        let planDate = isoFormatter.date(from: agenda.date) ?? Date()
        let dayString = dayFormatter.string(from: planDate)

        lines.append("\u{1F4CB} \(dayString) in \(city)")
        lines.append(agenda.weatherNote)
        lines.append("")

        // Slots
        for slot in agenda.slots {
            let emoji = slotEmoji(slot.type)
            lines.append("\(emoji) \(slot.time) \u{2014} \(slot.venueName)")
            if let travel = slot.travelNote, !travel.isEmpty {
                lines.append("   \(travel)")
            }
        }

        // Home activities (bad weather mode)
        if let home = agenda.homeActivities {
            lines.append("")
            lines.append("\u{1F3E0} Back home")
            if let baking = home.baking {
                lines.append("   \u{1F9C1} \(baking.idea)")
            }
            if let movie = home.movie {
                lines.append("   \u{1F3AC} \(movie.title)")
            }
            if let craft = home.craft {
                lines.append("   \u{2702}\u{FE0F} \(craft.idea)")
            }
        }

        lines.append("")
        lines.append("Made with Znuni")

        return lines.joined(separator: "\n")
    }

    private static func slotEmoji(_ type: AgendaSlot.SlotType) -> String {
        switch type {
        case .activity:     return "\u{1F3AF}"
        case .lunch:        return "\u{1F37D}\u{FE0F}"
        case .dinner:       return "\u{1F377}"
        case .homeActivity: return "\u{1F3E0}"
        }
    }
}
