import SwiftUI

/// Inline hero banner pill showing the current family session.
/// White 10% bg capsule with person icon + "Solo · Mia (5)" text.
struct SessionPillView: View {
    let session: FamilySession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: session.soloParent ? "person.fill" : "person.2.fill")
                    .font(.system(size: 11, weight: .medium))

                Text(session.childrenDisplay)
                    .font(.system(size: 12, weight: .medium))

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .opacity(0.5)
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
