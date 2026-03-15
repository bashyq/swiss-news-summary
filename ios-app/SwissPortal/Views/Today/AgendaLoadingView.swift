import SwiftUI

/// Skeleton shimmer matching the agenda timeline layout.
struct AgendaLoadingView: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        VStack(spacing: 0) {
            // 4 skeleton slot cards with connectors
            ForEach(0..<4, id: \.self) { index in
                skeletonCard
                if index < 3 {
                    skeletonConnector
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 2
            }
        }
    }

    private var skeletonCard: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot
            Circle()
                .fill(Color.znBorder)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 10) {
                // Eyebrow
                shimmerRect(width: 80, height: 10)

                // Venue name
                shimmerRect(width: 160, height: 16)

                // Reason
                shimmerRect(width: 220, height: 10)
                shimmerRect(width: 180, height: 10)

                // Tags
                HStack(spacing: 6) {
                    shimmerRect(width: 50, height: 18)
                    shimmerRect(width: 60, height: 18)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.znBorder, lineWidth: 1)
        )
    }

    private var skeletonConnector: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.znBorder.opacity(0.5))
                .frame(width: 2, height: 28)
                .padding(.leading, 14)

            shimmerRect(width: 90, height: 18)
                .clipShape(Capsule())

            Spacer()
        }
    }

    private func shimmerRect(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color.znBorder.opacity(0.6))
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: shimmerOffset * geo.size.width)
                }
                .clipped()
            )
    }
}
