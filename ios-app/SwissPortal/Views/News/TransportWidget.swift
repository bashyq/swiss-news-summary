import SwiftUI

/// Transport disruptions widget displayed in the News view.
///
/// Shows a single tappable status row. When there are delays, tapping opens
/// a sheet with the full delay list. When all clear, shows a green status.
struct TransportWidget: View {
    @Environment(AppState.self) private var appState

    let transport: Transport

    @State private var showDelaySheet = false

    var body: some View {
        Button {
            if !transport.delays.isEmpty {
                showDelaySheet = true
            }
        } label: {
            HStack(spacing: 9) {
                // Warning triangle
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.znTerracotta)

                Text(alertText)
                    .font(.system(size: 13))
                    .foregroundStyle(.znInk)
                    .lineLimit(1)

                Spacer()

                if !transport.delays.isEmpty {
                    // Arrow icon
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.znTerracotta)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.znTerracotta.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.znTerracotta.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDelaySheet) {
            TransportDelaySheet(transport: transport)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Helpers

    private var alertText: String {
        if transport.delays.isEmpty {
            return appState.localized(en: "Transport: All clear", de: "Verkehr: Alles in Ordnung")
        }
        // Show first delay as summary, like mockup
        if let first = transport.delays.first {
            let count = transport.summary.totalDelayed
            if count == 1 {
                return appState.localized(
                    en: "\(first.line) disruption — delays expected",
                    de: "\(first.line) Störung — Verspätungen erwartet"
                )
            } else {
                return appState.localized(
                    en: "\(count) disruptions — delays expected",
                    de: "\(count) Störungen — Verspätungen erwartet"
                )
            }
        }
        return ""
    }
}

// MARK: - Delay Sheet

private struct TransportDelaySheet: View {
    @Environment(AppState.self) private var appState

    let transport: Transport

    var body: some View {
        NavigationStack {
            List(transport.delays) { delay in
                HStack(spacing: 10) {
                    Text(delay.line)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 60, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(delay.destination)
                            .font(.subheadline)
                        Text(delay.scheduledTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer()

                    Text("+\(delay.delay) min")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(delayColor(delay.delay))
                        .clipShape(Capsule())
                }
            }
            .navigationTitle(appState.localized(en: "Delays", de: "Verspätungen"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func delayColor(_ minutes: Int) -> Color {
        if minutes >= 15 {
            return .znNegative
        } else if minutes >= 5 {
            return .znTerracotta
        } else {
            return .znTerracotta.opacity(0.75)
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
