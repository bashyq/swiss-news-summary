import Foundation
import CoreLocation

/// Maps lat/lon coordinates to approximate Zürich areas using Kreis centroids.
/// Used by the template engine and travel connector logic for geographic coherence.
enum ZurichArea: String, CaseIterable, Codable {
    case altstadt = "Altstadt"              // Kreis 1
    case enge = "Enge/Wollishofen"          // Kreis 2
    case wiedikon = "Wiedikon"              // Kreis 3
    case aussersihl = "Aussersihl"          // Kreis 4
    case industriequartier = "Industrie"    // Kreis 5
    case unterstrass = "Unterstrass"        // Kreis 6
    case fluntern = "Fluntern/Zoo"          // Kreis 7
    case seefeld = "Seefeld"               // Kreis 8
    case altstetten = "Altstetten"          // Kreis 9
    case hoengg = "Höngg"                   // Kreis 10
    case oerlikon = "Oerlikon"              // Kreis 11
    case schwamendingen = "Schwamendingen"  // Kreis 12

    // MARK: - Centroid coordinates (approximate)

    var centroid: CLLocationCoordinate2D {
        switch self {
        case .altstadt:         return CLLocationCoordinate2D(latitude: 47.3730, longitude: 8.5420)
        case .enge:             return CLLocationCoordinate2D(latitude: 47.3600, longitude: 8.5310)
        case .wiedikon:         return CLLocationCoordinate2D(latitude: 47.3630, longitude: 8.5180)
        case .aussersihl:       return CLLocationCoordinate2D(latitude: 47.3740, longitude: 8.5230)
        case .industriequartier: return CLLocationCoordinate2D(latitude: 47.3860, longitude: 8.5200)
        case .unterstrass:      return CLLocationCoordinate2D(latitude: 47.3930, longitude: 8.5370)
        case .fluntern:         return CLLocationCoordinate2D(latitude: 47.3850, longitude: 8.5650)
        case .seefeld:          return CLLocationCoordinate2D(latitude: 47.3620, longitude: 8.5530)
        case .altstetten:       return CLLocationCoordinate2D(latitude: 47.3870, longitude: 8.4890)
        case .hoengg:           return CLLocationCoordinate2D(latitude: 47.4020, longitude: 8.4940)
        case .oerlikon:         return CLLocationCoordinate2D(latitude: 47.4110, longitude: 8.5440)
        case .schwamendingen:   return CLLocationCoordinate2D(latitude: 47.4080, longitude: 8.5700)
        }
    }

    // MARK: - Adjacency

    /// Adjacent areas for geographic coherence in agenda planning.
    var adjacentAreas: [ZurichArea] {
        switch self {
        case .altstadt:         return [.enge, .aussersihl, .seefeld, .unterstrass]
        case .enge:             return [.altstadt, .wiedikon, .seefeld]
        case .wiedikon:         return [.enge, .aussersihl, .altstetten]
        case .aussersihl:       return [.altstadt, .wiedikon, .industriequartier]
        case .industriequartier: return [.aussersihl, .unterstrass, .altstetten, .hoengg]
        case .unterstrass:      return [.altstadt, .industriequartier, .fluntern, .oerlikon]
        case .fluntern:         return [.unterstrass, .seefeld, .schwamendingen]
        case .seefeld:          return [.altstadt, .enge, .fluntern]
        case .altstetten:       return [.wiedikon, .industriequartier, .hoengg]
        case .hoengg:           return [.industriequartier, .altstetten, .oerlikon]
        case .oerlikon:         return [.unterstrass, .hoengg, .schwamendingen]
        case .schwamendingen:   return [.oerlikon, .fluntern]
        }
    }

    // MARK: - Lookup

    /// Determine the approximate Zürich area for a coordinate.
    /// Returns nil if the coordinate is outside Zürich (>5km from city center).
    static func from(lat: Double, lon: Double) -> ZurichArea? {
        let location = CLLocation(latitude: lat, longitude: lon)
        let cityCenter = CLLocation(latitude: 47.3769, longitude: 8.5417)

        // Outside Zürich — too far from center
        guard location.distance(from: cityCenter) < 5000 else { return nil }

        // Find nearest centroid
        var nearest: ZurichArea = .altstadt
        var minDistance: Double = .infinity

        for area in ZurichArea.allCases {
            let centroidLoc = CLLocation(
                latitude: area.centroid.latitude,
                longitude: area.centroid.longitude
            )
            let dist = location.distance(from: centroidLoc)
            if dist < minDistance {
                minDistance = dist
                nearest = area
            }
        }
        return nearest
    }

    /// Estimate walk time in minutes between two areas.
    static func walkTimeMinutes(from: ZurichArea?, to: ZurichArea?) -> Int? {
        guard let from, let to else { return nil }
        if from == to { return 5 }
        if from.adjacentAreas.contains(to) { return 12 }
        return nil // too far to walk — suggest tram
    }

    /// Estimate travel description between two coordinates.
    static func travelDescription(
        fromLat: Double, fromLon: Double,
        toLat: Double, toLon: Double
    ) -> String {
        let fromArea = ZurichArea.from(lat: fromLat, lon: fromLon)
        let toArea = ZurichArea.from(lat: toLat, lon: toLon)

        let fromLoc = CLLocation(latitude: fromLat, longitude: fromLon)
        let toLoc = CLLocation(latitude: toLat, longitude: toLon)
        let distanceMeters = fromLoc.distance(from: toLoc)

        if distanceMeters < 800 {
            let walkMin = max(2, Int(distanceMeters / 80)) // ~80m/min walking
            return "🚶 \(walkMin) min walk"
        }

        if let walkTime = walkTimeMinutes(from: fromArea, to: toArea) {
            return "🚶 \(walkTime) min walk"
        }

        // Estimate tram time (~250m/min with stops)
        let tramMin = max(5, Int(distanceMeters / 250))
        return "🚃 ~\(tramMin) min by tram"
    }
}
