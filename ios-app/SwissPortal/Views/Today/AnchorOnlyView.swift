import SwiftUI

/// Shown when the user has anchors but zero fillable gaps remain.
///
/// Displays future anchor cards in a mini timeline. No AI suggestions, no "Let's go" button.
/// Per spec §9: "Future anchor cards only. No Let's go button. No AI suggestions."
struct AnchorOnlyView: View {
    @Environment(AppState.self) private var appState

    let anchors: [AnchorEvent]
    let onEdit: (AnchorEvent) -> Void
    let onDelete: (AnchorEvent) -> Void
    let onAdd: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f
    }()

    /// Only anchors that haven't ended yet.
    private var futureAnchors: [AnchorEvent] {
        let now = Date()
        return anchors
            .filter { $0.endTime > now }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status message
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.znPositive)

                Text(appState.localized(
                    en: "Your day is set — no open slots to fill.",
                    de: "Dein Tag steht — keine offenen Zeitfenster."
                ))
                .font(.system(size: 13))
                .foregroundStyle(.znBody)
            }
            .padding(.bottom, 16)

            // Future anchor cards
            if !futureAnchors.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(futureAnchors.enumerated()), id: \.element.id) { index, anchor in
                        anchorCard(anchor)

                        // Connector between cards
                        if index < futureAnchors.count - 1 {
                            connector(from: anchor, to: futureAnchors[index + 1])
                        }
                    }
                }
            }

            // Add anchor button
            if anchors.count < 5 {
                Button(action: onAdd) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text(appState.localized(en: "Add another", de: "Weitere hinzufügen"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.znTerracotta)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        Capsule()
                            .stroke(Color.znTerracotta.opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Anchor Card

    private func anchorCard(_ anchor: AnchorEvent) -> some View {
        Button {
            onEdit(anchor)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Timeline dot
                Circle()
                    .fill(accentColor(for: anchor.category))
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    // Eyebrow: category + time range
                    HStack(spacing: 4) {
                        Text(anchor.category.emoji)
                            .font(.system(size: 11))
                        Text(anchor.category.displayName.uppercased())
                            .font(.znEyebrow)
                            .foregroundStyle(.znMuted)
                        Spacer()
                        Text(timeRange(anchor))
                            .font(.znMono)
                            .foregroundStyle(.znNavy)
                    }

                    // Title
                    Text(anchor.title)
                        .font(.cardHeadline)
                        .foregroundStyle(.znInk)
                        .lineLimit(1)

                    // Neighbourhood
                    if let neighbourhood = anchor.neighbourhood, !neighbourhood.isEmpty {
                        Text(neighbourhood)
                            .font(.system(size: 12))
                            .foregroundStyle(.znMuted)
                    }

                    // Duration tag
                    HStack(spacing: 6) {
                        Text(durationLabel(anchor.durationMinutes))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.znNeutralTagText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.znNeutralTagBg)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                // Delete button
                Button {
                    onDelete(anchor)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.znMuted)
                        .frame(width: 22, height: 22)
                        .background(Color.znNeutralTagBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.cardPadding)
            .background(Color.znSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(Color.znBorder, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(
                    topLeadingRadius: AppSpacing.cardRadius,
                    bottomLeadingRadius: AppSpacing.cardRadius
                )
                .fill(accentColor(for: anchor.category))
                .frame(width: AppSpacing.borderStripWidth)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connector

    private func connector(from: AnchorEvent, to: AnchorEvent) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.znBorder.opacity(0.5))
                .frame(width: 2, height: 28)
                .padding(.leading, 14)

            let gapMinutes = Int(to.startTime.timeIntervalSince(from.endTime) / 60)
            if gapMinutes > 0 {
                Text(gapLabel(gapMinutes))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.znMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.znNeutralTagBg)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func timeRange(_ anchor: AnchorEvent) -> String {
        let start = Self.timeFormatter.string(from: anchor.startTime)
        let end = Self.timeFormatter.string(from: anchor.endTime)
        return "\(start)–\(end)"
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes % 60 == 0 {
            let hrs = minutes / 60
            return appState.localized(
                en: "\(hrs) hr\(hrs > 1 ? "s" : "")",
                de: "\(hrs) Std."
            )
        } else {
            let hrs = minutes / 60
            let mins = minutes % 60
            return appState.localized(
                en: "\(hrs)h \(mins)m",
                de: "\(hrs) Std. \(mins) Min."
            )
        }
    }

    private func gapLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hrs = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hrs)h"
            }
            return "\(hrs)h \(mins)m"
        }
    }

    private func accentColor(for category: AnchorCategory) -> Color {
        switch category {
        case .food: return .znTerracotta
        case .social: return .znNavy
        case .activity: return .znPositive
        case .errand: return .znMuted
        case .other: return .znBorder
        }
    }
}
