import Foundation

// MARK: - Deal

struct Deal: Codable, Identifiable {
    let id: String
    let name: String
    let nameDE: String
    let description: String
    let descriptionDE: String
    let category: String      // "museums", "outdoor", "transport", "family_passes", "seasonal"
    let type: DealType         // free, deal, tip
    let city: String           // city id or "all"
    let url: String?
    let validMonths: [Int]?    // nil = year-round

    func localizedName(language: AppLanguage) -> String {
        switch language {
        case .en: return name
        case .de: return nameDE
        }
    }

    func localizedDescription(language: AppLanguage) -> String {
        switch language {
        case .en: return description
        case .de: return descriptionDE
        }
    }

    /// Whether this deal is valid for the current month
    var isCurrentlyValid: Bool {
        guard let validMonths else { return true }
        let month = Calendar.current.component(.month, from: Date())
        return validMonths.contains(month)
    }

    /// Whether this deal applies to a given city
    func appliesTo(city: City) -> Bool {
        self.city == "all" || self.city == city.rawValue
    }
}

enum DealType: String, Codable, CaseIterable {
    case free
    case deal
    case tip

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .deal: return "Deal"
        case .tip: return "Tip"
        }
    }

    var displayNameDE: String {
        switch self {
        case .free: return "Gratis"
        case .deal: return "Angebot"
        case .tip: return "Tipp"
        }
    }

    var badgeColor: String {
        switch self {
        case .free: return "green"
        case .deal: return "blue"
        case .tip: return "amber"
        }
    }

    var sfSymbol: String {
        switch self {
        case .free: return "gift"
        case .deal: return "tag"
        case .tip: return "lightbulb"
        }
    }
}

// MARK: - Deal Filter

enum DealFilter: String, CaseIterable {
    case all
    case free
    case deal
    case tip

    var displayName: String {
        switch self {
        case .all: return "All"
        case .free: return "Free"
        case .deal: return "Deals"
        case .tip: return "Tips"
        }
    }

    var displayNameDE: String {
        switch self {
        case .all: return "Alle"
        case .free: return "Gratis"
        case .deal: return "Angebote"
        case .tip: return "Tipps"
        }
    }
}
