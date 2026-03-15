import Foundation
import CoreLocation

/// Builds and filters autocomplete suggestions for the anchor "What" field.
///
/// Sources (in priority order):
/// 1. City events happening today
/// 2. Recurring activities available today (excluding stayhome)
/// 3. Hardcoded family presets
struct AnchorSuggestionProvider {
    let activitiesData: ActivitiesResponse?
    let language: AppLanguage
    let today: Date

    // MARK: - Presets

    private static let presets: [(en: String, de: String)] = [
        ("Birthday party", "Geburtstagsfeier"),
        ("Playdate", "Spielverabredung"),
        ("Swimming", "Schwimmen"),
        ("Doctor appointment", "Arzttermin"),
        ("Music class", "Musikkurs"),
        ("Kinderkrippe pickup", "Kita-Abholung"),
        ("Nap time", "Mittagsschlaf"),
        ("Grandparents visit", "Besuch bei Grosseltern"),
    ]

    // MARK: - Build Suggestions

    /// All available suggestions (unfiltered), max ~30.
    func allSuggestions() -> [AnchorSuggestion] {
        var results: [AnchorSuggestion] = []

        // 1. City events overlapping today
        if let events = activitiesData?.cityEvents {
            let todayISO = Self.isoDateString(today)
            let todayEvents = events.filter { event in
                event.startDate <= todayISO && event.endDate >= todayISO
            }
            for event in todayEvents.prefix(6) {
                results.append(AnchorSuggestion(
                    id: "event-\(event.id)",
                    label: event.localizedName(language: language),
                    type: .cityEvent,
                    coordinate: nil // CityEvent has no coordinates
                ))
            }
        }

        // 2. Recurring activities available today
        if let activities = activitiesData?.activities {
            let recurring = activities.filter { activity in
                activity.recurring != nil
                && activity.isAvailable(on: today)
                && !activity.isStayHome
            }
            for activity in recurring.prefix(8) {
                let coord: CLLocationCoordinate2D? = activity.coordinate
                results.append(AnchorSuggestion(
                    id: "activity-\(activity.id)",
                    label: activity.localizedName(language: language),
                    type: .recurringActivity,
                    coordinate: coord
                ))
            }
        }

        // 3. Hardcoded presets
        for (i, preset) in Self.presets.enumerated() {
            let label = language == .de ? preset.de : preset.en
            results.append(AnchorSuggestion(
                id: "preset-\(i)",
                label: label,
                type: .preset,
                coordinate: nil
            ))
        }

        return results
    }

    /// Filter suggestions by query (case-insensitive substring match), max 6 results.
    func filtered(by query: String) -> [AnchorSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return Array(allSuggestions().prefix(6))
        }
        return Array(
            allSuggestions()
                .filter { $0.label.localizedCaseInsensitiveContains(trimmed) }
                .prefix(6)
        )
    }

    // MARK: - Neighbourhood Mapping

    /// Map ZurichArea to the neighbourhood chip labels used in AnchorFormSheet.
    static func nearestNeighbourhood(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let area = ZurichArea.from(lat: coordinate.latitude, lon: coordinate.longitude) else {
            return nil
        }
        return neighbourhoodLabel(for: area)
    }

    private static func neighbourhoodLabel(for area: ZurichArea) -> String {
        switch area {
        case .altstadt:         return "Kreis 1"
        case .enge:             return "Kreis 2"
        case .wiedikon:         return "Wiedikon"
        case .aussersihl:       return "Kreis 4"
        case .industriequartier: return "Kreis 5"
        case .unterstrass:      return "Kreis 6"
        case .fluntern:         return "Kreis 7"
        case .seefeld:          return "Seefeld"
        case .altstetten:       return "Altstetten"
        case .hoengg:           return "Kreis 8"   // Höngg not in the chip list, map to Kreis 8
        case .oerlikon:         return "Oerlikon"
        case .schwamendingen:   return "Kreis 3"   // Not in chip list, closest match
        }
    }

    private static func isoDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return formatter.string(from: date)
    }
}
