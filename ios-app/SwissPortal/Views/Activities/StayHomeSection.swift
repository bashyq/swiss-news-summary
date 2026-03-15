import SwiftUI

/// Grouped grid/list of stay-home activities organized by subcategory.
///
/// Each subcategory (sensory, art, active, pretend, kitchen) is an accordion card.
/// Collapsed: icon, category name, activity count, chevron.
/// Expanded: 2-column grid of activity tiles inside the card.
/// One category open at a time.
struct StayHomeSection: View {
    let activities: [Activity]
    let language: AppLanguage

    @State private var expandedCategory: String?

    var body: some View {
        if activities.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 10) {
                ForEach(groupedActivities, id: \.category) { group in
                    categoryCard(group)
                }
            }
        }
    }

    // MARK: - Category Card (accordion)

    private func categoryCard(_ group: ActivityGroup) -> some View {
        let isExpanded = expandedCategory == group.category

        return VStack(spacing: 0) {
            // Collapsed face — always visible
            HStack(spacing: 10) {
                // Icon circle
                Image(systemName: group.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(categoryColor(group.category))
                    .clipShape(Circle())

                // Name + count
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedCategoryName(group.category))
                        .font(.compactCardTitle)
                        .foregroundStyle(.znInk)

                    Text(language == .en
                         ? "\(group.activities.count) \(group.activities.count == 1 ? "activity" : "activities")"
                         : "\(group.activities.count) \(group.activities.count == 1 ? "Aktivität" : "Aktivitäten")")
                        .font(.system(size: 11))
                        .foregroundStyle(.znMuted)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.znChevron)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(AppAnimation.spring) {
                    expandedCategory = isExpanded ? nil : group.category
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: expandedCategory)

            // Expand panel — activity grid
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(group.activities) { activity in
                        StayHomeCard(activity: activity, language: language)
                    }
                }
                .padding(AppSpacing.cardPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.znBorder, lineWidth: 1)
        )
        .shadow(
            color: isExpanded ? AppShadow.cardExpanded.color : AppShadow.card.color,
            radius: isExpanded ? AppShadow.cardExpanded.radius : AppShadow.card.radius,
            x: 0,
            y: isExpanded ? AppShadow.cardExpanded.y : AppShadow.card.y
        )
    }

    // MARK: - Category Color

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "sensory": return .znTerracotta
        case "art": return .znNavy
        case "active": return .znPositive
        case "pretend": return Color(red: 0.6, green: 0.4, blue: 0.7)
        case "kitchen": return Color(red: 0.8, green: 0.55, blue: 0.2)
        default: return .znMuted
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
        case ("kitchen", .de): return "Küchenspass"
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
                .foregroundStyle(.znMuted)
            Text(language == .en
                 ? "No stay-home activities available"
                 : "Keine Zuhause-Aktivitäten verfügbar"
            )
            .font(.subheadline)
            .foregroundStyle(.znMuted)
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

/// A compact tile for a single stay-home activity inside an accordion card.
///
/// Shows the activity name, a brief description, and a materials list if available.
struct StayHomeCard: View {
    let activity: Activity
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Activity name
            Text(activity.localizedName(language: language))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.znInk)
                .lineLimit(2)

            // Description
            Text(activity.localizedDescription(language: language))
                .font(.system(size: 11))
                .foregroundStyle(.znBody)
                .lineLimit(3)

            Spacer(minLength: 0)

            // Materials
            if let materials = activity.localizedMaterials(language: language), !materials.isEmpty {
                Divider()
                    .padding(.vertical, 2)
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 8))
                        .foregroundStyle(.znTerracotta)
                    Text(materials)
                        .font(.system(size: 10))
                        .foregroundStyle(.znMuted)
                        .lineLimit(2)
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.znCream)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }
}

private func _stayHomeSample(_ id: String, _ name: String, _ desc: String, _ sub: String, _ mats: String?) -> Activity {
    Activity(id: id, name: name, nameDE: name, description: desc, descriptionDE: desc, indoor: true, ageRange: "2-5 years", duration: "30 min", price: "Free", priceDE: "Gratis", url: nil, lat: nil, lon: nil, category: "creative", minAge: 2, maxAge: 5, season: nil, free: true, recurring: nil, stayHome: true, availableMonths: nil, subcategory: sub, materials: mats, materialsDE: mats, addedDate: nil)
}

#Preview {
    let sampleActivities = [
        _stayHomeSample("s1", "Play Dough Fun", "Make shapes and creatures with colorful play dough.", "sensory", "Play dough, Cookie cutters"),
        _stayHomeSample("s2", "Water Play", "Pouring, splashing and measuring with cups and funnels.", "sensory", "Cups, Funnels, Water"),
        _stayHomeSample("a1", "Finger Painting", "Express creativity with washable finger paints.", "art", "Finger paints, Paper"),
        _stayHomeSample("a2", "Paper Collage", "Cut and glue colorful paper into pictures.", "art", "Scissors, Glue, Paper"),
        _stayHomeSample("ac1", "Obstacle Course", "Build a course with pillows, chairs and blankets.", "active", nil),
        _stayHomeSample("ac2", "Dance Party", "Put on music and dance together!", "active", nil),
        _stayHomeSample("p1", "Tea Party", "Set up a pretend tea party with stuffed animals.", "pretend", "Tea set, Stuffed animals"),
        _stayHomeSample("k1", "Cookie Decorating", "Decorate pre-made cookies with icing and sprinkles.", "kitchen", "Cookies, Icing, Sprinkles"),
    ]

    ScrollView {
        StayHomeSection(activities: sampleActivities, language: .en)
            .padding()
    }
}
