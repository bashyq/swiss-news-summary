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
            .fill(Color.znBorder)
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
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, x: AppShadow.subtle.x, y: AppShadow.subtle.y)
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
        .padding(AppSpacing.cardPadding)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, x: AppShadow.subtle.x, y: AppShadow.subtle.y)
        .shimmer()
    }
}

// MARK: - Skeleton Lunch Card

/// Placeholder matching the LunchCard layout
struct SkeletonLunchCard: View {
    var body: some View {
        HStack(spacing: 0) {
            // Photo thumbnail placeholder
            SkeletonBlock(width: 94, height: 90)

            // Body
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 140, height: 14)
                HStack(spacing: 5) {
                    SkeletonBlock(width: 12, height: 12)
                    SkeletonBlock(width: 40, height: 12)
                }
                SkeletonBlock(width: 80, height: 10)
                HStack(spacing: 6) {
                    SkeletonBlock(width: 60, height: 18)
                    SkeletonBlock(width: 50, height: 18)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            Spacer()
        }
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.znBorder, lineWidth: 1))
        .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, x: AppShadow.subtle.x, y: AppShadow.subtle.y)
        .shimmer()
    }
}
