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
            // Clock icon
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundStyle(.znTerracotta)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                // Header
                Text(appState.localized(
                    en: "This Day in History",
                    de: "Heute in der Geschichte"
                ))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.znTerracotta)
                .textCase(.uppercase)

                // Year + event
                (Text(String(history.year))
                    .foregroundStyle(.znTerracotta)
                    .fontWeight(.semibold)
                 + Text(" \u{2014} ")
                    .foregroundStyle(.secondary)
                 + Text(history.localizedEvent(language: appState.language))
                    .foregroundStyle(.secondary)
                )
                .font(.caption)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.znBorder, lineWidth: 1)
        )
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
