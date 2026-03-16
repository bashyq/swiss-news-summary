import SwiftUI

/// Config section for Plan mode, shown below the hero in the scroll area.
///
/// Contains weather, session, add-plans affordance, context banner, and weekend CTA.
/// Restyled for light background (moved out of the dark navy hero).
struct YourDayConfigSection: View {
    @Environment(AppState.self) private var appState

    let weather: Weather?
    let badWeatherMode: Bool
    let contextText: String?
    let sessionDisplay: String?
    let anchors: [AnchorEvent]
    let anchorCount: Int
    let canPlanWeekend: Bool
    let isWeekendMode: Bool

    let onWeatherTap: () -> Void
    let onSessionTap: () -> Void
    let onAnchorAdd: () -> Void
    var onAnchorEdit: ((AnchorEvent) -> Void)?
    var onAnchorDelete: ((AnchorEvent) -> Void)?
    var onPlanWeekend: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Context banner (AI summary — e.g. "Cold day — indoor activities recommended")
            if let contextText {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.znNavy.opacity(0.5))

                    Text(contextText)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.znBody)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.znNavy.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.znBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Session pill
            if let sessionDisplay {
                Button(action: onSessionTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text(sessionDisplay)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .opacity(0.4)
                    }
                    .foregroundStyle(Color.znInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.znNeutralTagBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Anchor pills — inline list with add/edit/delete
            AnchorPillRowView(
                anchors: anchors,
                onAdd: onAnchorAdd,
                onEdit: { anchor in onAnchorEdit?(anchor) },
                onDelete: { anchor in onAnchorDelete?(anchor) }
            )

            // "Plan the weekend" CTA
            if canPlanWeekend, !isWeekendMode, let onPlanWeekend {
                Button(action: onPlanWeekend) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                        Text(appState.localized(en: "Plan the weekend", de: "Wochenende planen"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.znTerracotta, Color.znTerracotta.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 6)
    }

    // MARK: - Weather Card

    private func weatherCard(_ weather: Weather) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: weather.sfSymbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(weather.temperature))°")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.znInk)

                    Text(weather.description)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.znBody)
                }

                if let high = weather.highTemp, let low = weather.lowTemp {
                    Text("H: \(Int(high))°  ·  L: \(Int(low))°")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.znMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.znChevron)
        }
        .padding(14)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.znBorder, lineWidth: 1)
        )
    }
}
