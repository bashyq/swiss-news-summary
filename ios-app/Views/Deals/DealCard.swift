import SwiftUI

/// Card view for a single deal.
///
/// Displays the deal name (localized), description (localized), type badge
/// (Free/green, Deal/blue, Tip/amber), category label, and an "Open" button
/// if a URL is available.
struct DealCard: View {
    let deal: Deal
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardContent
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: type badge + category
            headerRow

            // Deal name
            Text(deal.localizedName(language: language))
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Description
            Text(deal.localizedDescription(language: language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Footer: seasonal badge + open URL button
            footerRow
        }
        .padding(14)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 8) {
            // Type badge
            typeBadge

            // Category label
            Text(categoryDisplayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            // Type icon
            Image(systemName: deal.type.sfSymbol)
                .font(.caption)
                .foregroundStyle(typeColor)
        }
    }

    // MARK: - Type Badge

    private var typeBadge: some View {
        let label: String
        switch language {
        case .en: label = deal.type.displayName
        case .de: label = deal.type.displayNameDE
        }

        return Text(label)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(typeColor.opacity(0.15))
            .foregroundStyle(typeColor)
            .clipShape(Capsule())
    }

    // MARK: - Footer Row

    private var footerRow: some View {
        HStack {
            // Seasonal indicator
            if let months = deal.validMonths, !months.isEmpty {
                BadgeView(
                    text: seasonalLabel(months: months),
                    icon: "calendar",
                    color: .teal
                )
            }

            Spacer()

            // Open URL button
            if let urlString = deal.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text(language == .en ? "Open" : "Offnen")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
    }

    // MARK: - Helpers

    private var typeColor: Color {
        Color.badgeColor(for: deal.type.badgeColor)
    }

    private var categoryDisplayName: String {
        switch deal.category {
        case "museums": return language == .en ? "Museums" : "Museen"
        case "outdoor": return language == .en ? "Outdoor" : "Outdoor"
        case "transport": return language == .en ? "Transport" : "Verkehr"
        case "family_passes": return language == .en ? "Family Passes" : "Familienpasse"
        case "seasonal": return language == .en ? "Seasonal" : "Saisonal"
        default: return deal.category.capitalized
        }
    }

    private func seasonalLabel(months: [Int]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        let monthNames = months.compactMap { month -> String? in
            var components = DateComponents()
            components.month = month
            components.day = 1
            guard let date = Calendar.current.date(from: components) else { return nil }
            return formatter.string(from: date)
        }

        if monthNames.count <= 3 {
            return monthNames.joined(separator: ", ")
        } else {
            return "\(monthNames.first ?? "") - \(monthNames.last ?? "")"
        }
    }
}

#Preview {
    let sampleDeal = Deal(
        id: "kunsthaus-free-wed",
        name: "Kunsthaus Zurich - Free Wednesdays",
        nameDE: "Kunsthaus Zurich - Gratis Mittwoch",
        description: "Free entry to the permanent collection every Wednesday.",
        descriptionDE: "Jeden Mittwoch freier Eintritt in die Sammlung.",
        category: "museums",
        type: .free,
        city: "zurich",
        url: "https://www.kunsthaus.ch",
        validMonths: nil
    )

    VStack(spacing: 12) {
        DealCard(deal: sampleDeal, language: .en)

        DealCard(
            deal: Deal(
                id: "tip-snacks",
                name: "Pack Your Own Snacks",
                nameDE: "Eigene Snacks mitnehmen",
                description: "Save CHF 15-30 per outing by packing snacks and drinks.",
                descriptionDE: "Spare CHF 15-30 pro Ausflug.",
                category: "outdoor",
                type: .tip,
                city: "all",
                url: nil,
                validMonths: [5, 6, 7, 8, 9]
            ),
            language: .en
        )
    }
    .padding()
}
