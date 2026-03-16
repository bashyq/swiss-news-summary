import SwiftUI

/// Banner shown after a timeline shift when feasibility issues are detected.
///
/// Follows the same pattern as `ReflowBanner` — shows one warning at a time
/// with two action buttons. Priority: dinner too late > venue closed > duration squeezed.
struct TrimSuggestionBanner: View {
    @Environment(AppState.self) private var appState

    let warning: FeasibilityWarning
    let onAccept: () -> Void    // Apply the suggested resolution
    let onDismiss: () -> Void   // Keep the timeline as is

    var body: some View {
        VStack(spacing: 12) {
            // Warning icon + message
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: warningIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.znTerracotta)
                    .frame(width: 20)

                Text(warning.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.znInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if warning.suggestedResolution != nil {
                HStack(spacing: 12) {
                    // Accept resolution
                    Button(action: onAccept) {
                        Text(acceptLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color.znTerracotta)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    // Keep as is
                    Button(action: onDismiss) {
                        Text(appState.localized(en: "Keep as is", de: "Beibehalten"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.znBody)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color.znCream)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.znBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.znTerracotta.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.znTerracotta.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var warningIcon: String {
        switch warning.type {
        case .dinnerTooLate: return "clock.badge.exclamationmark"
        case .venueClosedAtShiftedTime: return "door.left.hand.closed"
        case .activityDurationSqueezed: return "timer"
        }
    }

    private var acceptLabel: String {
        switch warning.suggestedResolution {
        case .skipSlot:
            return appState.localized(en: "Yes, skip it", de: "Ja, überspringen")
        case .shortenSlot:
            return appState.localized(en: "Shorten visit", de: "Besuch kürzen")
        case .none:
            return ""
        }
    }
}
