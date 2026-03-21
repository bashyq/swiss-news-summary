import SwiftUI

/// Config section for Plan mode, shown below the hero in the scroll area.
///
/// Contains weather, session, add-plans affordance, context banner, and weekend CTA.
/// Restyled for light background (moved out of the dark navy hero).
struct YourDayConfigSection: View {
    @Environment(AppState.self) private var appState

    let weather: Weather?
    let badWeatherMode: Bool
    let sessionDisplay: String?
    let anchors: [AnchorEvent]
    let anchorCount: Int
    let onWeatherTap: () -> Void
    let onSessionTap: () -> Void
    let onAnchorAdd: () -> Void
    var onAnchorEdit: ((AnchorEvent) -> Void)?
    var onAnchorDelete: ((AnchorEvent) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
