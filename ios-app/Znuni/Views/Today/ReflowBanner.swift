import SwiftUI

/// Banner shown after a custom slot edit, asking the user to rebuild or keep downstream slots.
struct ReflowBanner: View {
    @Environment(AppState.self) private var appState

    let slotType: String
    let onRebuild: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(appState.localized(
                en: "\(slotType.capitalized) updated. Recalculate the rest of the day?",
                de: "\(slotType.capitalized) aktualisiert. Rest des Tages neu berechnen?"
            ))
            .font(.system(size: 13))
            .foregroundStyle(.znInk)
            .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                // Rebuild
                Button(action: onRebuild) {
                    Text(appState.localized(en: "Rebuild", de: "Neu planen"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.znNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Keep
                Button(action: onKeep) {
                    Text(appState.localized(en: "Keep as is", de: "Beibehalten"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.znBody)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.znCream)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.znBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.znTerracotta.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.znTerracotta.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
