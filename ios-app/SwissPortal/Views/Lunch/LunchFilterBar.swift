import SwiftUI

/// Horizontal scrollable filter bar for the Lunch view.
///
/// Displays all `LunchFilter` cases as tappable chips with localized labels,
/// SF Symbol icons, and count badges. Updates `viewModel.filter` on selection.
struct LunchFilterBar: View {
    @Bindable var viewModel: LunchViewModel
    let language: AppLanguage
    var savedIDs: Set<String> = []

    var body: some View {
        FilterBar(
            filters: LunchFilter.allCases,
            selected: viewModel.filter,
            label: { filter in
                localizedLabel(for: filter)
            },
            icon: { filter in
                filter.sfSymbol
            },
            count: { filter in
                filterCount(for: filter)
            },
            onSelect: { filter in
                withAnimation(AppAnimation.standardEase) {
                    viewModel.filter = filter
                }
            }
        )
    }

    // MARK: - Localized Label

    private func localizedLabel(for filter: LunchFilter) -> String {
        switch language {
        case .en: return filter.displayName
        case .de: return filter.displayNameDE
        }
    }

    // MARK: - Filter Count

    private func filterCount(for filter: LunchFilter) -> Int? {
        guard let spots = viewModel.lunchData?.spots else { return nil }
        switch filter {
        case .all, .nearMe: return nil // Don't show count for All/Near Me
        case .saved: return spots.filter { savedIDs.contains($0.id) }.count
        case .open: return spots.filter { $0.openForLunch == true }.count
        case .outdoor: return spots.filter { $0.outdoorSeating == true }.count
        case .vegetarian: return spots.filter { $0.vegetarian == "yes" }.count
        }
    }
}

#Preview {
    LunchFilterBar(
        viewModel: LunchViewModel(),
        language: .en
    )
}
