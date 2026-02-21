import SwiftUI

/// Horizontal scrollable filter bar for the Activities view.
///
/// Displays all `ActivityFilter` cases as tappable chips with localized labels
/// and SF Symbol icons. Updates `viewModel.filter` on selection.
struct ActivityFilterBar: View {
    @Bindable var viewModel: ActivitiesViewModel
    let language: AppLanguage

    var body: some View {
        FilterBar(
            filters: ActivityFilter.allCases,
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

    private func localizedLabel(for filter: ActivityFilter) -> String {
        switch language {
        case .en: return filter.displayName
        case .de: return filter.displayNameDE
        }
    }
}

#Preview {
    ActivityFilterBar(
        viewModel: ActivitiesViewModel(),
        language: .en
    )
}
