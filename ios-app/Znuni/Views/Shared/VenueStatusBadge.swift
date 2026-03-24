import SwiftUI

/// Capsule badge showing real-time open/closed status for venues.
/// Uses `OpeningHoursParser` for client-side parsing of OSM opening_hours strings.
/// Falls back to server-computed `openForLunch` for lunch spots when no hours string exists.
/// Shows nothing (EmptyView) when status is unknown.
struct VenueStatusBadge: View {
    @Environment(AppState.self) private var appState

    let openingHours: String?

    /// Optional server-computed value (for lunch spots with no parseable hours).
    var serverOpenForLunch: Bool? = nil

    /// When true, renders with a leading "·" separator for embedding in an HStack row.
    var inline: Bool = false

    /// When true, renders as a high-contrast pill badge (for title-row placement).
    var prominent: Bool = false

    private var status: VenueStatus {
        // Prefer client-side parsing when openingHours string exists
        let parsed = OpeningHoursParser.status(from: openingHours)
        if parsed != .unknown { return parsed }
        // Fall back to server value for lunch spots
        if let serverValue = serverOpenForLunch {
            return serverValue ? .open : .closed
        }
        return .unknown
    }

    var body: some View {
        switch status {
        case .open:
            badge(
                color: .znPositive,
                text: appState.localized(en: "Open", de: "Geöffnet")
            )
        case .closed:
            badge(
                color: .znNegative,
                text: appState.localized(en: "Closed", de: "Geschlossen")
            )
        case .unknown:
            EmptyView()
        }
    }

    private func badge(color: Color, text: String) -> some View {
        Group {
            if prominent {
                prominentBadge(color: color, text: text)
            } else {
                dotBadge(color: color, text: text)
            }
        }
    }

    private func dotBadge(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            if inline {
                Text("·")
                    .foregroundStyle(.znMuted)
            }
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private func prominentBadge(color: Color, text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
