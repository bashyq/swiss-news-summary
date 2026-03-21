import SwiftUI

/// Card view for a city event or festival.
///
/// Displays the event name (localized, bold), date range, description,
/// badges (toddler-friendly, free), an open URL button,
/// and a "Plan around this" CTA for plannable events happening today.
struct EventCard: View {
    @Environment(AppState.self) private var appState

    let event: CityEvent

    @State private var showAnchorForm = false

    /// Whether this event is plannable and hasn't ended yet.
    private var showAddToPlan: Bool {
        guard event.isPlannable else { return false }
        guard let endDate = event.endDateParsed else { return true }
        return Calendar.current.startOfDay(for: endDate) >= Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: name + external link
            headerRow

            // Date range
            dateRange

            // Description
            Text(event.localizedDescription(language: appState.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Badges
            badgesRow

            // "Plan around this" CTA
            if showAddToPlan {
                addToPlanButton
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, x: AppShadow.subtle.x, y: AppShadow.subtle.y)
        .contentShape(Rectangle())
        .onTapGesture {
            openURL()
        }
        .sheet(isPresented: $showAnchorForm) {
            AnchorFormSheet(
                event: event,
                language: appState.language
            ) { anchor in
                AnchorStore.shared.add(anchor, for: anchor.startTime)
                // Navigate to Today tab with the event's date
                if let startDate = DateHelpers.parseISO(event.startDate) {
                    appState.pendingPlanDate = startDate
                }
                appState.selectedTab = .today
            }
            .environment(appState)
            .presentationDetents([.large])
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "party.popper.fill")
                .font(.caption)
                .foregroundStyle(.brand)
                .frame(width: 20, height: 20)

            Text(event.localizedName(language: appState.language))
                .font(.cardTitle)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if event.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Date Range

    private var dateRange: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if event.startDate == event.endDate {
                Text(event.startDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(event.startDate) - \(event.endDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Badges Row

    private var badgesRow: some View {
        HStack(spacing: 6) {
            if event.toddlerFriendly {
                ToddlerFriendlyBadge()
            }

            if event.free {
                FreeBadge()
            }

            // City badge
            BadgeView(
                text: event.city.capitalized,
                icon: "mappin",
                color: .znNavy.opacity(0.7)
            )
        }
    }

    // MARK: - Add to Plan

    private var addToPlanButton: some View {
        Button {
            showAnchorForm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.caption2)
                Text(appState.localized(
                    en: "Plan around this \u{2192}",
                    de: "Darum planen \u{2192}"
                ))
                .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.znNavy)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.znNavy.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openURL() {
        guard let urlString = event.url,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    EventCard(event: PreviewData.cityEvent)
        .padding()
        .environment(AppState())
}
