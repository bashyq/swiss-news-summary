import Foundation
import CoreLocation

/// A single autocomplete suggestion for the anchor "What" field.
struct AnchorSuggestion: Identifiable {
    let id: String
    let label: String
    let type: SuggestionType
    let coordinate: CLLocationCoordinate2D?
    /// Suggested anchor category when this suggestion is selected.
    let defaultCategory: AnchorCategory
    /// Suggested duration in minutes when this suggestion is selected.
    let defaultDuration: Int

    enum SuggestionType {
        case cityEvent
        case recurringActivity
        case preset

        var sfSymbol: String {
            switch self {
            case .cityEvent: return "calendar"
            case .recurringActivity: return "arrow.trianglehead.2.clockwise"
            case .preset: return "sparkle"
            }
        }

        func badgeText(language: AppLanguage) -> String {
            switch self {
            case .cityEvent:
                return language == .de ? "Event" : "Event"
            case .recurringActivity:
                return language == .de ? "Wiederkehrend" : "Recurring"
            case .preset:
                return language == .de ? "Vorschlag" : "Suggestion"
            }
        }
    }
}
