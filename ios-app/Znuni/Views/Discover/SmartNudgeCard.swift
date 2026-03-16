import SwiftUI

/// Contextual nudge card shown at the top of the Discover tab.
/// Displays proactive suggestions (sunshine escape, fresh snow, upcoming events)
/// with appropriate gradient backgrounds and CTA buttons.
struct SmartNudgeCard: View {
    let nudge: Nudge
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: nudge.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(nudge.title)
                        .font(.cardHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(nudge.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Text(nudge.ctaLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(AppSpacing.cardPadding)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        }
        .buttonStyle(.plain)
    }

    private var gradient: LinearGradient {
        switch nudge.type {
        case .sunshineEscape:
            return LinearGradient(
                colors: [.sunshineGradientStart, .sunshineGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .freshSnow:
            return LinearGradient(
                colors: [.snowGradientStart, .snowGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .upcomingEvent:
            return LinearGradient(
                colors: [.eventsGradientStart, .eventsGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
