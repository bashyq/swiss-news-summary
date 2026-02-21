import SwiftUI

/// Horizontal scrollable filter bar for the Lunch view.
///
/// Displays all `LunchFilter` cases as tappable chips with localized labels
/// and SF Symbol icons. Updates `viewModel.filter` on selection.
struct LunchFilterBar: View {
    @Bindable var viewModel: LunchViewModel
    let language: AppLanguage

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
            onSelect: { filter in
                withAnimation(.easeInOut(duration: 0.2)) {
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
}

#Preview {
    LunchFilterBar(
        viewModel: LunchViewModel(),
        language: .en
    )
}
