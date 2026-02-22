import SwiftUI

/// Segmented picker for filtering activities by age range.
///
/// Options: All ages, 2-3 years (toddler), 4-5 years (preschool).
/// Binds to `viewModel.ageFilter` for immediate filtering.
struct AgeFilterPicker: View {
    @Bindable var viewModel: ActivitiesViewModel
    let language: AppLanguage

    var body: some View {
        Picker(
            language == .en ? "Age range" : "Altersgruppe",
            selection: $viewModel.ageFilter
        ) {
            ForEach(AgeFilter.allCases, id: \.self) { ageFilter in
                Text(localizedLabel(for: ageFilter))
                    .tag(ageFilter)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Localized Label

    private func localizedLabel(for filter: AgeFilter) -> String {
        switch language {
        case .en: return filter.displayName
        case .de: return filter.displayNameDE
        }
    }
}

#Preview {
    AgeFilterPicker(
        viewModel: ActivitiesViewModel(),
        language: .en
    )
    .padding()
}
