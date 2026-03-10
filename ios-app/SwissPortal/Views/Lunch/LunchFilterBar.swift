import SwiftUI

/// Filter bar for the Lunch view — multi-select toggle pills + cuisine dropdown.
///
/// Toggle pills (Near Me, Open, Terrace, Saved) can be freely combined with AND logic.
/// The cuisine picker is a single-select Menu that filters by `cuisineCategory`.
struct LunchFilterBar: View {
    @Bindable var viewModel: LunchViewModel
    let language: AppLanguage
    var savedIDs: Set<String> = []

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Toggle pills (multi-select)
                ForEach(LunchToggle.allCases) { toggle in
                    FilterChip(
                        label: localizedLabel(for: toggle),
                        isSelected: viewModel.activeToggles.contains(toggle),
                        icon: toggle.sfSymbol,
                        action: {
                            withAnimation(AppAnimation.standardEase) {
                                if viewModel.activeToggles.contains(toggle) {
                                    viewModel.activeToggles.remove(toggle)
                                } else {
                                    viewModel.activeToggles.insert(toggle)
                                }
                            }
                        }
                    )
                }

                // Cuisine dropdown (single-select)
                cuisineMenu
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Cuisine Menu

    private var cuisineMenu: some View {
        Menu {
            ForEach(CuisineFilter.allCases) { cuisine in
                Button {
                    withAnimation(AppAnimation.standardEase) {
                        viewModel.cuisineFilter = cuisine
                    }
                } label: {
                    HStack {
                        Text(localizedCuisineLabel(for: cuisine))
                        if viewModel.cuisineFilter == cuisine {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.caption2)
                Text(viewModel.cuisineFilter == .all
                     ? localizedCuisineLabel(for: .all)
                     : localizedCuisineLabel(for: viewModel.cuisineFilter))
                    .font(.caption)
                    .fontWeight(viewModel.cuisineFilter != .all ? .semibold : .regular)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if viewModel.cuisineFilter != .all {
                    LinearGradient.brand
                } else {
                    LinearGradient(colors: [Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
                }
            }
            .foregroundStyle(viewModel.cuisineFilter != .all ? .white : .primary)
            .clipShape(Capsule())
            .scaleEffect(viewModel.cuisineFilter != .all ? AppAnimation.selectedScale : 1.0)
            .animation(AppAnimation.spring, value: viewModel.cuisineFilter)
        }
    }

    // MARK: - Localized Labels

    private func localizedLabel(for toggle: LunchToggle) -> String {
        switch language {
        case .en: return toggle.displayName
        case .de: return toggle.displayNameDE
        }
    }

    private func localizedCuisineLabel(for cuisine: CuisineFilter) -> String {
        switch language {
        case .en: return cuisine.displayName
        case .de: return cuisine.displayNameDE
        }
    }
}

#Preview {
    LunchFilterBar(
        viewModel: LunchViewModel(),
        language: .en
    )
}
