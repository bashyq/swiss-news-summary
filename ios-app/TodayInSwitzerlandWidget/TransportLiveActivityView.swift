import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity configuration for transport disruptions.
///
/// Displays train delays on the Lock Screen and Dynamic Island so users
/// can monitor disruptions at a glance during commutes.
struct TransportLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransportActivityAttributes.self) { context in
            // MARK: - Lock Screen / Banner UI
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.totalDelayed) delays", systemImage: "tram.fill")
                        .font(.headline)
                        .foregroundStyle(statusColor(context.state.status))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("Max: +\(context.state.maxDelay)m")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(context.state.topDelays) { delay in
                            HStack {
                                Text(delay.line)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(delay.destination)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text("+\(delay.delay)m")
                                    .font(.caption.bold())
                                    .foregroundStyle(delayColor(delay.delay))
                            }
                        }
                    }
                }
            } compactLeading: {
                // MARK: - Compact Leading
                Image(systemName: "tram.fill")
                    .foregroundStyle(statusColor(context.state.status))
            } compactTrailing: {
                // MARK: - Compact Trailing
                Text("+\(context.state.maxDelay)m")
                    .font(.caption.bold())
                    .foregroundStyle(delayColor(context.state.maxDelay))
            } minimal: {
                // MARK: - Minimal
                Image(systemName: "tram.fill")
                    .foregroundStyle(statusColor(context.state.status))
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TransportActivityAttributes>) -> some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundStyle(statusColor(context.state.status))
                Text("Transport")
                    .font(.headline)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(context.attributes.cityName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                statusBadge(context.state.status)
            }

            Divider()

            // Delay rows
            VStack(alignment: .leading, spacing: 4) {
                ForEach(context.state.topDelays) { delay in
                    HStack {
                        Text(delay.line)
                            .font(.subheadline.bold())
                            .frame(width: 50, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(delay.destination)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(delay.scheduledTime)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("+\(delay.delay)m")
                            .font(.subheadline.bold())
                            .foregroundStyle(delayColor(delay.delay))
                    }
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.7))
        .activitySystemActionForegroundColor(.white)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let label: String = switch status {
        case "minor": "Minor"
        case "major": "Major"
        default: "OK"
        }

        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.2))
            .foregroundStyle(statusColor(status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "none": return .green
        case "minor": return .yellow
        case "major": return .red
        default: return .gray
        }
    }

    private func delayColor(_ minutes: Int) -> Color {
        if minutes >= 10 { return .red }
        if minutes >= 5 { return .orange }
        return .yellow
    }
}
