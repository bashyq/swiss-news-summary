import SwiftUI

/// Slim banner shown when new calendar events are detected after the plan is already built.
struct CalendarSyncBanner: View {
    let eventCount: Int
    let onSync: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 14))
                .foregroundStyle(Color.znNavy)

            Text(eventCount == 1
                ? "New calendar event detected"
                : "\(eventCount) new calendar events detected")
                .font(.system(size: 13))
                .foregroundStyle(Color.znInk)

            Spacer()

            Button("Sync") {
                onSync()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.znNavy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.znNavy.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }
}
