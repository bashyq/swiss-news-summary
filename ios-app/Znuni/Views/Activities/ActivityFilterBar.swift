import SwiftUI

/// Horizontal scrollable filter bar for the Activities view.
///
/// Displays all `ActivityFilter` cases as tappable chips with localized labels
/// and SF Symbol icons. Updates `viewModel.filter` on selection.
struct ActivityFilterBar: View {
    @Bindable var viewModel: ActivitiesViewModel
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
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
            count: { filter in
                filterCount(for: filter)
            },
            onSelect: { filter in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.filter = filter
                }
            }
        )
    }

    private func filterCount(for filter: ActivityFilter) -> Int? {
        guard let activities = viewModel.activitiesData?.activities else { return nil }
        let count: Int
        switch filter {
        case .all:
            count = activities.filter { !$0.isStayHome }.count
        case .indoor:
            count = activities.filter { $0.indoor && !$0.isStayHome }.count
        case .outdoor:
            count = activities.filter { !$0.indoor && !$0.isStayHome }.count
        case .free:
            count = activities.filter { $0.isFree && !$0.isStayHome }.count
        case .saved:
            let activityIDs = Set(activities.map(\.id))
            count = appState.savedActivityIDs.filter { activityIDs.contains($0) }.count
        case .seasonal:
            count = activities.filter { $0.isCurrentSeason && !$0.isStayHome }.count
        case .stayHome:
            count = activities.filter { $0.isStayHome }.count
        case .nearMe:
            if let userLocation = locationManager.location {
                count = activities.filter { activity in
                    guard !activity.isStayHome,
                          let distance = activity.distance(from: userLocation) else { return false }
                    return distance <= 2000
                }.count
            } else {
                count = activities.filter { !$0.isStayHome }.count
            }
        }
        return count > 0 ? count : nil
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
