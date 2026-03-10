import SwiftUI

/// Weekend brief card shown in the News view.
///
/// Displays Saturday/Sunday weather forecasts and up to 3 weekend events.
/// Tapping navigates to the Events tab. Hidden on Sundays (API returns null).
struct WeekendBriefCard: View {
    @Environment(AppState.self) private var appState

    let brief: WeekendBrief

    var body: some View {
        Button {
            appState.selectedTab = .more
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text(appState.localized(en: "This Weekend", de: "Dieses Wochenende"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Weather badges for Sat + Sun
                HStack(spacing: 12) {
                    if let sat = brief.saturday {
                        dayBadge(
                            label: appState.localized(en: "Sat", de: "Sa"),
                            day: sat
                        )
                    }
                    if let sun = brief.sunday {
                        dayBadge(
                            label: appState.localized(en: "Sun", de: "So"),
                            day: sun
                        )
                    }
                    Spacer()
                }

                // Up to 3 events
                if !brief.events.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(brief.events.prefix(3))) { event in
                            eventRow(event)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.purple.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Badge

    private func dayBadge(label: String, day: WeekendBriefDay) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Image(systemName: day.sfSymbol)
                .font(.caption)
                .symbolRenderingMode(.multicolor)

            Text("\(day.tempMax)°/\(day.tempMin)°")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    // MARK: - Event Row

    private func eventRow(_ event: WeekendBriefEvent) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.purple)
                .frame(width: 5, height: 5)

            Text(event.localizedName(language: appState.language))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)

            if event.toddlerFriendly == true {
                Image(systemName: "figure.and.child.holdinghands")
                    .font(.caption2)
                    .foregroundStyle(.brand)
            }

            if event.free == true {
                Text(appState.localized(en: "Free", de: "Gratis"))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
        }
    }
}
