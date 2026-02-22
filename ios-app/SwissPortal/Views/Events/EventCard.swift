import SwiftUI

/// Card view for a city event or festival.
///
/// Displays the event name (localized, bold), date range, description,
/// badges (toddler-friendly, free), and an open URL button.
/// Used in both the filtered events list and the day detail panel.
struct EventCard: View {
    @Environment(AppState.self) private var appState

    let event: CityEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: name + external link
            headerRow

            // Date range
            dateRange

            // Description
            if let description = event.localizedDescription(language: appState.language) {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Badges
            badgesRow
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            openURL()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "party.popper.fill")
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 20, height: 20)

            Text(event.localizedName(language: appState.language))
                .font(.subheadline)
                .fontWeight(.semibold)
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
            if event.toddlerFriendly == true {
                ToddlerFriendlyBadge()
            }

            if event.free == true {
                FreeBadge()
            }

            // City badge
            BadgeView(
                text: event.city.capitalized,
                icon: "mappin",
                color: .teal
            )
        }
    }

    // MARK: - Actions

    private func openURL() {
        guard let urlString = event.url,
              let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    let sampleEvent = CityEvent(
        id: "zh-sechselaeuten",
        name: "Sechseläuten",
        nameDE: "Sechseläuten",
        city: "zurich",
        startDate: "2026-04-20",
        endDate: "2026-04-20",
        description: "Zurich's traditional spring festival with the burning of the Böögg snowman.",
        descriptionDE: "Zürichs traditionelles Frühlingsfest mit der Verbrennung des Böögg.",
        toddlerFriendly: true,
        free: true,
        url: "https://www.sechselaeuten.ch/"
    )

    VStack {
        EventCard(event: sampleEvent)
            .padding()
    }
    .environment(AppState())
}
