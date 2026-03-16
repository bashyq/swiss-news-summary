import SwiftUI

struct SnowHeroCard: View {
    private var isSnowSeason: Bool {
        let month = Calendar.current.component(.month, from: Date())
        return month >= 11 || month <= 4
    }

    var body: some View {
        if isSnowSeason {
            cardContent
        }
    }

    private var cardContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Where's the snow?")
                    .font(.cardHeadline)
                    .foregroundStyle(.white)
                Text("Fresh powder & ski conditions")
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
                colors: [.snowGradientStart, .snowGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }
}
