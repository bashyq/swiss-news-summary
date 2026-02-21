import SwiftUI

/// Reusable badge for labels (free, distance, drive time, etc.)
struct BadgeView: View {
    let text: String
    var icon: String?
    var color: Color = .gray
    var style: BadgeStyle = .filled

    enum BadgeStyle {
        case filled
        case outlined
    }

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(background)
        .foregroundStyle(foreground)
        .clipShape(Capsule())
    }

    private var background: some ShapeStyle {
        switch style {
        case .filled: return AnyShapeStyle(color.opacity(0.15))
        case .outlined: return AnyShapeStyle(.clear)
        }
    }

    private var foreground: Color {
        switch style {
        case .filled: return color
        case .outlined: return color
        }
    }
}

/// Sentiment badge for news items
struct SentimentBadge: View {
    let sentiment: String?

    var body: some View {
        if let sentiment, sentiment != "neutral" {
            BadgeView(
                text: sentiment.capitalized,
                icon: sentiment == "positive" ? "arrow.up.right" : "arrow.down.right",
                color: Color.sentimentColor(sentiment)
            )
        }
    }
}

/// Drive time badge
struct DriveTimeBadge: View {
    let minutes: Int

    var body: some View {
        BadgeView(
            text: CLLocation.formattedDriveTime(minutes),
            icon: "car.fill",
            color: .blue
        )
    }
}

import CoreLocation

/// Distance badge (from user location)
struct DistanceBadge: View {
    let meters: Double

    var body: some View {
        BadgeView(
            text: CLLocation.formattedDistance(meters),
            icon: "location.fill",
            color: .teal
        )
    }
}

/// Altitude badge
struct AltitudeBadge: View {
    let meters: Int

    var body: some View {
        BadgeView(
            text: "\(meters)m",
            icon: "mountain.2.fill",
            color: .brown
        )
    }
}

/// Free badge
struct FreeBadge: View {
    var body: some View {
        BadgeView(text: "Free", icon: "gift", color: .green)
    }
}

/// Toddler-friendly badge
struct ToddlerFriendlyBadge: View {
    var body: some View {
        BadgeView(text: "Toddler-friendly", icon: "figure.and.child.holdinghands", color: .purple)
    }
}
