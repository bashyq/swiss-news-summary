import Foundation

// MARK: - Venue Type

/// The kind of venue that was visited.
enum VenueType: String, Codable {
    case activity
    case restaurant
    case curatedEvent
}

// MARK: - Visit Source

/// How the visit was recorded — determines weight in freshness scoring.
enum VisitSource: String, Codable {
    case executionCheckIn   // "Done ✓" tap — confirmed visit, full weight
    case manualMark         // "We've been here" button — confirmed, full weight
    case planCompletion     // reached end of execution — assumed, 50% weight
}

// MARK: - Venue Visit

/// A single recorded visit to a venue. Persisted locally and synced to KV.
struct VenueVisit: Codable, Identifiable {
    let id: UUID
    let profileId: String
    let venueId: String
    let venueName: String
    let venueType: VenueType
    let visitDate: Date
    let source: VisitSource
    let weatherCondition: String?
    let familySnapshot: String          // "Sami(3)" — for future analytics

    init(
        id: UUID = UUID(),
        profileId: String = "bisho",
        venueId: String,
        venueName: String,
        venueType: VenueType,
        visitDate: Date = Date(),
        source: VisitSource,
        weatherCondition: String? = nil,
        familySnapshot: String = ""
    ) {
        self.id = id
        self.profileId = profileId
        self.venueId = venueId
        self.venueName = venueName
        self.venueType = venueType
        self.visitDate = visitDate
        self.source = source
        self.weatherCondition = weatherCondition
        self.familySnapshot = familySnapshot
    }
}
