import SwiftUI

/// Shown when all day-part windows have elapsed and no future anchors remain.
///
/// Displays a calm "day is done" message. No "Let's go" button, no AI suggestions.
/// Per spec §9: "That's your day — enjoy your evening."
struct DayCompleteView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 24)

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.znNavy, Color.znNavy.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(appState.localized(
                en: "That's your day — enjoy your evening.",
                de: "Das war's — geniess den Abend."
            ))
            .font(.sectionHeadline)
            .foregroundStyle(.znInk)
            .multilineTextAlignment(.center)

            Text(appState.localized(
                en: "All time slots have passed. See you tomorrow!",
                de: "Alle Zeitfenster sind vorbei. Bis morgen!"
            ))
            .font(.system(size: 14))
            .foregroundStyle(.znBody)
            .multilineTextAlignment(.center)

            Spacer()
                .frame(height: 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}
