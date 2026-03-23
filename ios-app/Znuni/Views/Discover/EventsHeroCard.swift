import SwiftUI

struct EventsHeroCard: View {
    let upcomingCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("What's happening?")
                    .font(.cardHeadline)
                    .foregroundStyle(.white)
                Text("Events, markets & more")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            if upcomingCount > 0 {
                Text("\(upcomingCount) this week")
                    .font(.znLabel)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(AppSpacing.cardPadding)
        .background(
            LinearGradient(
                colors: [.eventsGradientStart, .eventsGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }
}
