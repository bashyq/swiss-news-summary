import SwiftUI

/// A subtle banner showing a "This Day in History" fact.
///
/// Displays the year and the localized event text in a compact
/// row with a muted background.
struct HistoryBanner: View {
    @Environment(AppState.self) private var appState

    let history: HistoryFact

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Calendar icon
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.purple.opacity(0.8))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                // Header
                Text(appState.localized(
                    en: "This Day in History",
                    de: "Heute in der Geschichte"
                ))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.purple.opacity(0.8))
                .textCase(.uppercase)

                // Year + event
                Text("\(String(history.year)) \u{2014} \(history.localizedEvent(language: appState.language))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let sampleHistory = HistoryFact(
        year: 1958,
        event: "Switzerland's first nuclear reactor begins operation at the University of Geneva.",
        eventDE: "Der erste Schweizer Kernreaktor nimmt an der Universität Genf den Betrieb auf."
    )

    HistoryBanner(history: sampleHistory)
        .padding()
        .environment(AppState())
}
