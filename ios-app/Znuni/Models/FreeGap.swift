import Foundation

// MARK: - Suggestion Type

/// What kind of venue should fill a free gap. Determined deterministically
/// by `GapAnalysisEngine` — Claude never decides slot type.
enum SuggestionType: String, Codable {
    case morningActivity
    case lunch
    case afternoonActivity
    case dinner
    case quickActivity
}

// MARK: - Free Gap

/// A period of unscheduled time between anchors (or day boundaries).
/// Produced by `GapAnalysisEngine.analyse()`.
struct FreeGap: Identifiable {
    let id: UUID
    let gapStart: Date
    let gapEnd: Date
    let effectiveStart: Date        // max(gapStart, now + 15min)
    let effectiveMinutes: Int
    let precedingAnchor: AnchorEvent?
    let followingAnchor: AnchorEvent?
    let suggestedType: SuggestionType?
    let isFillable: Bool
}
