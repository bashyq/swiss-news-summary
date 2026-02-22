import SwiftUI

// MARK: - Shimmer Modifier

/// Adds a left-to-right shimmer animation over placeholder content.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 300)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shapes

/// A rounded rectangle placeholder block
private struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
    }
}

// MARK: - Skeleton News Card

/// Placeholder matching the NewsCard layout
struct SkeletonNewsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Headline
            SkeletonBlock(height: 16)
            SkeletonBlock(width: 200, height: 16)

            // Summary
            SkeletonBlock(height: 12)
            SkeletonBlock(width: 260, height: 12)

            // Metadata row
            HStack(spacing: 6) {
                SkeletonBlock(width: 60, height: 20)
                SkeletonBlock(width: 40, height: 12)
                Spacer()
                SkeletonBlock(width: 50, height: 20)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .shimmer()
    }
}

// MARK: - Skeleton Activity Card

/// Placeholder matching the ActivityCard layout
struct SkeletonActivityCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + name + heart
            HStack(spacing: 8) {
                SkeletonBlock(width: 20, height: 20)
                SkeletonBlock(width: 160, height: 16)
                Spacer()
                SkeletonBlock(width: 24, height: 24)
            }

            // Description
            SkeletonBlock(height: 12)
            SkeletonBlock(width: 220, height: 12)

            // Badges
            HStack(spacing: 6) {
                SkeletonBlock(width: 60, height: 20)
                SkeletonBlock(width: 70, height: 20)
                SkeletonBlock(width: 50, height: 20)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .shimmer()
    }
}

// MARK: - Skeleton Lunch Card

/// Placeholder matching the LunchCard layout
struct SkeletonLunchCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + name + heart
            HStack(spacing: 8) {
                SkeletonBlock(width: 20, height: 20)
                SkeletonBlock(width: 180, height: 16)
                Spacer()
                SkeletonBlock(width: 24, height: 24)
            }

            // Details row: cuisine badge + hours + open badge
            HStack(spacing: 8) {
                SkeletonBlock(width: 70, height: 20)
                SkeletonBlock(width: 90, height: 12)
                Spacer()
                SkeletonBlock(width: 80, height: 20)
            }

            // Badges
            HStack(spacing: 6) {
                SkeletonBlock(width: 80, height: 20)
                SkeletonBlock(width: 70, height: 20)
            }

            // Star rating
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonBlock(width: 14, height: 14)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .shimmer()
    }
}
