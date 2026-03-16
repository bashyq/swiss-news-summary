import Foundation

/// Represents a city that the planner can compose agendas for.
/// Wraps `City` enum but also provides a static check for whether
/// a given destination ID maps to a covered city.
struct PlanningCity: Equatable, Hashable {
    let city: City

    var id: String { city.id }
    var name: String { city.displayName }

    func localizedName(language: AppLanguage) -> String {
        city.localizedName(language: language)
    }

    static let zurich = PlanningCity(city: .zurich)

    /// All cities that the planner supports (same as City.allCases).
    static let coveredCities: [PlanningCity] = City.allCases.map { PlanningCity(city: $0) }

    /// Check whether a destination ID matches one of the 7 covered cities.
    /// Used to gate the "Plan a day here" CTA on sunshine/snow cards.
    static func isCovered(_ destinationId: String) -> Bool {
        let id = destinationId.lowercased()
        return City.allCases.contains { $0.rawValue == id }
    }

    /// Look up a PlanningCity from a destination ID, if covered.
    static func from(destinationId: String) -> PlanningCity? {
        let id = destinationId.lowercased()
        guard let city = City(rawValue: id) else { return nil }
        return PlanningCity(city: city)
    }
}
