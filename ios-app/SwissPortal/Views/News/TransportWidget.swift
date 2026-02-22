import SwiftUI

/// Transport disruptions widget displayed in the News view.
///
/// Shows a status summary with a colored badge (none/minor/major) and a
/// collapsible list of individual train delays. When there are no delays,
/// a green "All clear" message is displayed instead.
struct TransportWidget: View {
    @Environment(AppState.self) private var appState

    let transport: Transport

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if transport.delays.isEmpty {
                allClearBanner
            } else {
                delayDisclosure
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - All Clear

    private var allClearBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(appState.localized(en: "Transport: All clear", de: "Verkehr: Alles in Ordnung"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
    }

    // MARK: - Delay Disclosure Group

    private var delayDisclosure: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                Divider()
                    .padding(.vertical, 4)

                ForEach(transport.delays) { delay in
                    delayRow(delay)
                    if delay.id != transport.delays.last?.id {
                        Divider()
                            .padding(.leading, 36)
                    }
                }
            }
        } label: {
            statusHeader
        }
        .tint(.secondary)
        .padding(12)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "tram.fill")
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            // Status badge
            BadgeView(
                text: statusBadgeText,
                color: statusColor
            )
        }
    }

    // MARK: - Delay Row

    private func delayRow(_ delay: TrainDelay) -> some View {
        HStack(spacing: 10) {
            // Line name
            Text(delay.line)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(width: 52, alignment: .leading)

            // Destination
            Text(delay.destination)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            // Scheduled time
            Text(delay.scheduledTime)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            // Delay badge
            Text("+\(delay.delay) min")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(delayColor(delay.delay))
                .clipShape(Capsule())
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        Color.transportStatus(transport.summary.status)
    }

    private var statusText: String {
        let count = transport.summary.totalDelayed
        return appState.localized(
            en: "\(count) delay\(count == 1 ? "" : "s")",
            de: "\(count) Verspätung\(count == 1 ? "" : "en")"
        )
    }

    private var statusBadgeText: String {
        switch transport.summary.status {
        case "minor":
            return appState.localized(en: "Minor", de: "Gering")
        case "major":
            return appState.localized(en: "Major", de: "Erheblich")
        default:
            return appState.localized(en: "OK", de: "OK")
        }
    }

    private func delayColor(_ minutes: Int) -> Color {
        if minutes >= 15 {
            return .red
        } else if minutes >= 5 {
            return .orange
        } else {
            return .yellow
        }
    }
}

#Preview {
    let sampleTransport = Transport(
        delays: [
            TrainDelay(line: "IC 8", destination: "Bern", delay: 5, scheduledTime: "14:02"),
            TrainDelay(line: "S3", destination: "Effretikon", delay: 12, scheduledTime: "14:15"),
            TrainDelay(line: "IR 37", destination: "Basel SBB", delay: 3, scheduledTime: "14:22")
        ],
        summary: TransportSummary(totalDelayed: 3, maxDelay: 12, status: "minor")
    )

    VStack(spacing: 16) {
        TransportWidget(transport: sampleTransport)

        TransportWidget(transport: Transport(
            delays: [],
            summary: TransportSummary(totalDelayed: 0, maxDelay: 0, status: "none")
        ))
    }
    .padding()
    .environment(AppState())
}
