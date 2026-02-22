import SwiftUI

/// The Weekend Planner view — shows Saturday and Sunday activity plans based on weather.
///
/// Displays weather forecasts for each day along with suggested morning and afternoon activities.
/// Users can shuffle for new suggestions via the toolbar button.
struct WeekendView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager

    @State private var viewModel = WeekendViewModel()

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    shuffleButton
                }
            }
            .refreshable {
                await viewModel.loadWeekend(
                    city: appState.city,
                    language: appState.language
                )
            }
            .task {
                await viewModel.loadWeekend(
                    city: appState.city,
                    language: appState.language
                )
            }
            .onChange(of: appState.city) { _, _ in
                Task {
                    await viewModel.loadWeekend(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
            .onChange(of: appState.language) { _, _ in
                Task {
                    await viewModel.loadWeekend(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        appState.localized(en: "Weekend Planner", de: "Wochenendplaner")
    }

    // MARK: - Toolbar Buttons

    private var shuffleButton: some View {
        Button {
            Task {
                await viewModel.shuffle(
                    city: appState.city,
                    language: appState.language
                )
            }
        } label: {
            Image(systemName: "shuffle")
        }
        .disabled(viewModel.isLoading)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.weekendData == nil {
            LoadingView(message: appState.localized(
                en: "Planning your weekend...",
                de: "Wochenende planen..."
            ))
        } else if let error = viewModel.error, viewModel.weekendData == nil {
            ErrorView(message: error) {
                Task {
                    await viewModel.loadWeekend(
                        city: appState.city,
                        language: appState.language
                    )
                }
            }
        } else if let data = viewModel.weekendData {
            weekendContent(data)
        } else {
            emptyState
        }
    }

    // MARK: - Weekend Content

    private func weekendContent(_ data: WeekendResponse) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // City header
                cityHeader

                // Inline loading indicator for background refresh
                if viewModel.isLoading {
                    InlineLoadingView()
                }

                // Saturday card
                WeekendDayCard(
                    day: data.saturday,
                    dayLabel: appState.localized(en: "Saturday", de: "Samstag"),
                    language: appState.language
                )

                // Sunday card
                WeekendDayCard(
                    day: data.sunday,
                    dayLabel: appState.localized(en: "Sunday", de: "Sonntag"),
                    language: appState.language
                )

                // Shuffle hint
                shuffleHint
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    // MARK: - City Header

    private var cityHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.purple)
            Text(appState.city.localizedName(language: appState.language))
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Shuffle Hint

    private var shuffleHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "shuffle")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(appState.localized(
                en: "Tap shuffle for new suggestions",
                de: "Tippe auf Mischen fur neue Vorschlage"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(appState.localized(
                en: "No weekend plan available",
                de: "Kein Wochenendplan verfugbar"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    NavigationStack {
        WeekendView()
            .environment(AppState())
            .environment(LocationManager())
    }
}
