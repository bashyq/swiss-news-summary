import SwiftUI
import UIKit

// MARK: - Gradient Presets

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.brand, .brandDark], startPoint: .leading, endPoint: .trailing
    )
}

// MARK: - ShapeStyle conformance (enables `.brand` shorthand in .foregroundStyle etc.)

extension ShapeStyle where Self == Color {
    static var brand: Color { Color.brand }
    static var brandDark: Color { Color.brandDark }
}

/// App color palette — adapts to light/dark mode automatically
extension Color {
    // MARK: - Brand Colors (matches website accent: #dc2626 light / #e53e3e dark)

    static let brand = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.898, green: 0.243, blue: 0.243, alpha: 1) // #e53e3e
            : UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1) // #dc2626
    })

    static let brandDark = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.725, green: 0.110, blue: 0.110, alpha: 1) // #b91c1c
            : UIColor(red: 0.600, green: 0.106, blue: 0.106, alpha: 1) // #991b1b
    })

    // MARK: - Primary Colors
    static let appPrimary = Color.brand
    static let appAccent = Color.brand

    // MARK: - Semantic Colors (fallback values if asset catalog not configured)

    /// Brand accent used for baseline/highlights
    static let baseline = Color.brand

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

    // MARK: - Card Border Colors

    static func activityBorderColor(indoor: Bool, isFree: Bool) -> Color {
        if isFree { return .green }
        return indoor ? .blue : .orange
    }

    static func cuisineBorderColor(_ category: String?) -> Color {
        switch category?.lowercased() {
        case "swiss": return .red
        case "italian": return .green
        case "asian": return .orange
        case "kebab": return .brown
        case "cafe": return .purple
        case "vegetarian": return .mint
        case "fastfood": return .yellow
        default: return .blue
        }
    }
}
