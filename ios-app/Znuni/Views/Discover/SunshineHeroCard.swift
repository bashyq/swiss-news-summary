import SwiftUI

struct SunshineHeroCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Where's the sun?")
                    .font(.cardHeadline)
                    .foregroundStyle(.white)
                Text("Find the sunniest spot nearby")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(AppSpacing.cardPadding)
        .background(
            LinearGradient(
                colors: [.sunshineGradientStart, .sunshineGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }
}
