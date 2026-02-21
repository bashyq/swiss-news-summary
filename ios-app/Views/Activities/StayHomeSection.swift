import SwiftUI

/// Grouped grid/list of stay-home activities organized by subcategory.
///
/// Groups activities by subcategory (sensory, art, active, pretend, kitchen)
/// and displays each as a simple card with name, description, and materials list.
struct StayHomeSection: View {
    let activities: [Activity]
    let language: AppLanguage

    var body: some View {
        if activities.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 20) {
                ForEach(groupedActivities, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        // Subcategory header
                        subcategoryHeader(group.category, icon: group.icon)

                        // Activity cards in a 2-column grid
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(group.activities) { activity in
                                StayHomeCard(activity: activity, language: language)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subcategory Header

    private func subcategoryHeader(_ category: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.purple)
            Text(localizedCategoryName(category))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Grouping

    private var groupedActivities: [ActivityGroup] {
        let subcategories = ["sensory", "art", "active", "pretend", "kitchen"]
        var groups: [ActivityGroup] = []

        for subcategory in subcategories {
            let matching = activities.filter {
                ($0.subcategory?.lowercased() ?? "") == subcategory
            }
            if !matching.isEmpty {
                groups.append(ActivityGroup(
                    category: subcategory,
                    icon: subcategoryIcon(for: subcategory),
                    activities: matching
                ))
            }
        }

        // Add any activities that don't match known subcategories
        let knownCategories = Set(subcategories)
        let uncategorized = activities.filter {
            guard let sub = $0.subcategory?.lowercased() else { return true }
            return !knownCategories.contains(sub)
        }
        if !uncategorized.isEmpty {
            groups.append(ActivityGroup(
                category: "other",
                icon: "star.fill",
                activities: uncategorized
            ))
        }

        return groups
    }

    // MARK: - Helpers

    private func subcategoryIcon(for subcategory: String) -> String {
        switch subcategory {
        case "sensory": return "hand.raised.fingers.spread.fill"
        case "art": return "paintpalette.fill"
        case "active": return "figure.run"
        case "pretend": return "theatermasks.fill"
        case "kitchen": return "fork.knife"
        default: return "star.fill"
        }
    }

    private func localizedCategoryName(_ category: String) -> String {
        switch (category, language) {
        case ("sensory", .en): return "Sensory Play"
        case ("sensory", .de): return "Sinnesspiele"
        case ("art", .en): return "Art & Craft"
        case ("art", .de): return "Kunst & Basteln"
        case ("active", .en): return "Active Play"
        case ("active", .de): return "Bewegungsspiele"
        case ("pretend", .en): return "Pretend Play"
        case ("pretend", .de): return "Rollenspiele"
        case ("kitchen", .en): return "Kitchen Fun"
        case ("kitchen", .de): return "Kuchenspass"
        case ("other", .en): return "Other"
        case ("other", .de): return "Sonstiges"
        default: return category.capitalized
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sofa.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(language == .en
                 ? "No stay-home activities available"
                 : "Keine Zuhause-Aktivitaten verfugbar"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Activity Group

private struct ActivityGroup: Identifiable {
    let category: String
    let icon: String
    let activities: [Activity]

    var id: String { category }
}

// MARK: - Stay Home Card

/// A compact card for a single stay-home activity.
///
/// Shows the activity name, a brief description, and a materials list if available.
struct StayHomeCard: View {
    let activity: Activity
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Activity name
            Text(activity.localizedName(language: language))
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Description
            Text(activity.localizedDescription(language: language))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Materials list
            if let materials = activity.localizedMaterials(language: language), !materials.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text(language == .en ? "Materials:" : "Material:")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.purple)

                    ForEach(materials, id: \.self) { material in
                        HStack(alignment: .top, spacing: 4) {
                            Text("\u{2022}")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(material)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    let sampleActivities = [
        Activity(
            id: "sensory-1",
            name: "Play Dough Fun",
            nameDE: "Knete-Spass",
            description: "Make shapes and creatures with colorful play dough.",
            descriptionDE: "Formen und Kreaturen aus bunter Knete herstellen.",
            indoor: true,
            ageRange: "2-5 years",
            duration: "30-60 min",
            price: "Free",
            priceDE: "Gratis",
            url: nil,
            lat: nil,
            lon: nil,
            category: "creative",
            minAge: 2,
            maxAge: 5,
            season: nil,
            free: true,
            recurring: nil,
            stayHome: true,
            subcategory: "sensory",
            materials: ["Play dough", "Cookie cutters", "Rolling pin"],
            materialsDE: ["Knete", "Ausstechformen", "Nudelholz"]
        ),
        Activity(
            id: "art-1",
            name: "Finger Painting",
            nameDE: "Fingermalerei",
            description: "Express creativity with washable finger paints on large paper.",
            descriptionDE: "Kreativitat mit abwaschbaren Fingerfarben auf grossem Papier.",
            indoor: true,
            ageRange: "2-5 years",
            duration: "30-45 min",
            price: "Free",
            priceDE: "Gratis",
            url: nil,
            lat: nil,
            lon: nil,
            category: "creative",
            minAge: 2,
            maxAge: 5,
            season: nil,
            free: true,
            recurring: nil,
            stayHome: true,
            subcategory: "art",
            materials: ["Finger paints", "Large paper", "Old clothes"],
            materialsDE: ["Fingerfarben", "Grosses Papier", "Alte Kleidung"]
        )
    ]

    ScrollView {
        StayHomeSection(activities: sampleActivities, language: .en)
            .padding()
    }
}
