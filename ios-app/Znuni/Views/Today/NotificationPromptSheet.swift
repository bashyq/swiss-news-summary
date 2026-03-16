import SwiftUI

/// Custom in-app explanation shown before requesting notification permission.
///
/// "Want a nudge when it's time to leave for your next stop?"
/// Shown once on first "Let's go" tap. If declined, never shown again.
struct NotificationPromptSheet: View {
    @Environment(AppState.self) private var appState

    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "bell.badge")
                .font(.system(size: 36))
                .foregroundStyle(Color.znNavy)
                .padding(.top, 8)

            // Title
            Text(appState.localized(
                en: "Stay on schedule",
                de: "Im Zeitplan bleiben"
            ))
            .font(.custom("Playfair", size: 22))
            .foregroundStyle(.znInk)

            // Explanation
            Text(appState.localized(
                en: "Want a nudge when it's time to leave for your next stop? Znüni can remind you — no other notifications.",
                de: "Möchtest du eine Erinnerung, wenn es Zeit ist, zum nächsten Stopp aufzubrechen? Znüni erinnert dich — keine anderen Benachrichtigungen."
            ))
            .font(.system(size: 14))
            .foregroundStyle(.znBody)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)

            Spacer()

            // Buttons
            VStack(spacing: 10) {
                Button(action: onAccept) {
                    Text(appState.localized(en: "Turn on reminders", de: "Erinnerungen aktivieren"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.znNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(action: onDecline) {
                    Text(appState.localized(en: "Not now", de: "Nicht jetzt"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.znMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }
}
