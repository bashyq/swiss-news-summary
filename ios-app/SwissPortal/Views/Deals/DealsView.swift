import SwiftUI

/// The Deals & Free view — curated list of free entry spots, family passes, and money-saving tips.
///
/// Uses static data from `DealsData.all` (no API call). Supports filtering by type
/// (All, Free, Deals, Tips) and shows only deals relevant to the selected city and current month.
struct DealsView: View {
    @Environment(AppState.self) private var appState

    @State private var viewModel = DealsViewModel()

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "Deals & Free", de: "Angebote & Gratis")
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            // 1. Filter bar
            filterBar
                .padding(.top, 8)

            // 2. Deal count
            dealCountLabel

            // 3. Deal list
            dealList
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        FilterBar(
            filters: DealFilter.allCases,
            selected: viewModel.filter,
            label: { filter in
                appState.language == .en ? filter.displayName : filter.displayNameDE
            },
            icon: { filter in
                filterIcon(for: filter)
            },
            onSelect: { filter in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.filter = filter
                }
            }
        )
    }

    private func filterIcon(for filter: DealFilter) -> String {
        switch filter {
        case .all: return "square.grid.2x2"
        case .free: return "gift"
        case .deal: return "tag"
        case .tip: return "lightbulb"
        }
    }

    // MARK: - Deal Count Label

    private var dealCountLabel: some View {
        let deals = currentDeals
        return HStack {
            Text(appState.localized(
                en: "\(deals.count) results",
                de: "\(deals.count) Ergebnisse"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Deal List

    private var dealList: some View {
        let deals = currentDeals

        return Group {
            if deals.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(deals) { deal in
                            DealCard(deal: deal, language: appState.language)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Current Deals

    private var currentDeals: [Deal] {
        viewModel.filteredDeals(city: appState.city)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(appState.localized(
                en: "No deals found",
                de: "Keine Angebote gefunden"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Text(appState.localized(
                en: "Try changing the filter or city",
                de: "Versuche einen anderen Filter oder eine andere Stadt"
            ))
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    NavigationStack {
        DealsView()
            .environment(AppState())
    }
}
