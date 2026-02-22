import SwiftUI

/// App color palette — adapts to light/dark mode automatically
extension Color {
    // MARK: - Primary Colors
    static let appPrimary = Color("AppPrimary", bundle: nil)
    static let appAccent = Color.purple

    // MARK: - Semantic Colors (fallback values if asset catalog not configured)

    /// Purple accent used for baseline/highlights
    static let baseline = Color.purple

    /// Green for positive sentiment, free badges
    static let positive = Color.green

    /// Red for negative sentiment, major disruptions
    static let negative = Color.red

    /// Amber/orange for tips, school holidays
    static let amber = Color.orange

    /// Weather card background
    static let weatherCard = Color.blue.opacity(0.1)

    // MARK: - Badge Colors

    static func badgeColor(for type: String) -> Color {
        switch type {
        case "green": return .green
        case "red": return .red
        case "blue": return .blue
        case "amber", "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "gray": return .gray
        default: return .gray
        }
    }

    // MARK: - Transport Status

    static func transportStatus(_ status: String) -> Color {
        switch status {
        case "none": return .green
        case "minor": return .yellow
        case "major": return .red
        default: return .gray
        }
    }

    // MARK: - Sunshine Colors

    static func sunshineColor(hours: Double) -> Color {
        if hours > 6 { return .orange }
        if hours > 3 { return .blue }
        return .gray
    }

    // MARK: - Snow Colors

    static func snowColor(cm: Double) -> Color {
        if cm > 30 { return Color(red: 0.1, green: 0.2, blue: 0.8) } // Deep blue
        if cm > 10 { return Color(red: 0.3, green: 0.5, blue: 0.9) } // Blue
        return .gray
    }

    // MARK: - Sentiment

    static func sentimentColor(_ sentiment: String?) -> Color {
        switch sentiment {
        case "positive": return .green
        case "negative": return .red
        default: return .gray
        }
    }

    // MARK: - Category Colors

    static func categoryColor(_ key: String) -> Color {
        switch key {
        case "topStories": return .blue
        case "politics": return .purple
        case "disruptions": return .red
        case "events": return .green
        case "culture": return .orange
        case "local": return .teal
        default: return .gray
        }
    }
}
