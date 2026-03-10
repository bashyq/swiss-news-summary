import SwiftUI

/// A gradient hero banner with layered SF Symbols for visual branding.
/// Used at the top of each main tab to give the app a distinct identity.
struct HeroBanner: View {
    let style: Style

    enum Style {
        case news
        case activities
        case lunch
        case sunshine
        case snow

        var gradient: [Color] {
            switch self {
            case .news: return [Color.brand, Color.brand.opacity(0.7)]
            case .activities: return [.orange, .pink]
            case .lunch: return [Color(red: 0.2, green: 0.7, blue: 0.4), .teal]
            case .sunshine: return [.orange, .yellow]
            case .snow: return [Color(red: 0.3, green: 0.5, blue: 0.9), Color(red: 0.6, green: 0.8, blue: 1.0)]
            }
        }

        /// Large background symbol (decorative)
        var backgroundSymbol: String {
            switch self {
            case .news: return "newspaper.fill"
            case .activities: return "figure.play"
            case .lunch: return "fork.knife"
            case .sunshine: return "sun.max.fill"
            case .snow: return "snowflake"
            }
        }

        /// Array of small scattered symbols for visual depth
        var scatterSymbols: [String] {
            switch self {
            case .news: return ["globe.europe.africa.fill", "quote.opening", "chart.line.uptrend.xyaxis"]
            case .activities: return ["star.fill", "heart.fill", "paintbrush.fill"]
            case .lunch: return ["leaf.fill", "cup.and.saucer.fill", "star.fill"]
            case .sunshine: return ["cloud.fill", "mountain.2.fill", "car.fill"]
            case .snow: return ["mountain.2.fill", "figure.skiing.downhill", "snowflake"]
            }
        }

        var tagline: (en: String, de: String) {
            switch self {
            case .news: return ("Your daily Swiss briefing", "Dein tägliches Schweiz-Briefing")
            case .activities: return ("Fun for little explorers", "Spass für kleine Entdecker")
            case .lunch: return ("Discover local flavors", "Lokale Geschmäcker entdecken")
            case .sunshine: return ("Chase the weekend sun", "Der Wochenendsonne entgegen")
            case .snow: return ("Fresh powder awaits", "Frischer Pulverschnee wartet")
            }
        }
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: style.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Large background symbol — faded, offset right
            Image(systemName: style.backgroundSymbol)
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.15))
                .offset(x: 100, y: -5)
                .rotationEffect(.degrees(-10))

            // Scattered small symbols
            scatteredSymbols

            // Foreground content
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Main icon
                    Image(systemName: style.backgroundSymbol)
                        .font(.title2)
                        .foregroundStyle(.white)

                    // Swiss cross flag element
                    swissCross
                        .padding(.top, 2)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Swiss Cross

    private var swissCross: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(.white)
                .frame(width: 12, height: 4)
            RoundedRectangle(cornerRadius: 2)
                .fill(.white)
                .frame(width: 4, height: 12)
        }
        .opacity(0.6)
    }

    // MARK: - Scattered Symbols

    private var scatteredSymbols: some View {
        let positions: [(x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double, opacity: Double)] = [
            (x: -40, y: -12, size: 14, rotation: -15, opacity: 0.2),
            (x: 30, y: 18, size: 11, rotation: 20, opacity: 0.15),
            (x: 70, y: -20, size: 13, rotation: -8, opacity: 0.18),
        ]

        return ZStack {
            ForEach(Array(zip(style.scatterSymbols.indices, style.scatterSymbols)), id: \.0) { index, symbol in
                if index < positions.count {
                    let pos = positions[index]
                    Image(systemName: symbol)
                        .font(.system(size: pos.size))
                        .foregroundStyle(.white.opacity(pos.opacity))
                        .rotationEffect(.degrees(pos.rotation))
                        .offset(x: pos.x, y: pos.y)
                }
            }
        }
    }
}

// MARK: - Section Header with SF Symbol Composition

/// A visually rich section header with a large multicolor SF Symbol and title.
struct IllustratedSectionHeader: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let tint: Color

    init(_ symbol: String, title: String, subtitle: String? = nil, tint: Color = .primary) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .symbolRenderingMode(.multicolor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Emoji Scene

/// A decorative emoji composition used in empty states or onboarding moments.
struct EmojiScene: View {
    let emojis: [String]
    let size: CGFloat

    init(_ emojis: [String], size: CGFloat = 32) {
        self.emojis = emojis
        self.size = size
    }

    var body: some View {
        HStack(spacing: size * 0.15) {
            ForEach(Array(emojis.enumerated()), id: \.offset) { index, emoji in
                Text(emoji)
                    .font(.system(size: size - CGFloat(abs(index - emojis.count / 2)) * 4))
                    .rotationEffect(.degrees(Double(index - emojis.count / 2) * 5))
                    .offset(y: CGFloat(abs(index - emojis.count / 2)) * 3)
            }
        }
    }
}

#Preview("Hero Banners") {
    VStack(spacing: 12) {
        HeroBanner(style: .news)
        HeroBanner(style: .activities)
        HeroBanner(style: .lunch)
        HeroBanner(style: .sunshine)
        HeroBanner(style: .snow)
    }
    .padding()
}

#Preview("Section Headers") {
    VStack(spacing: 16) {
        IllustratedSectionHeader("sun.max.fill", title: "Weekend Sunshine", subtitle: "Fri–Sun forecast", tint: .orange)
        IllustratedSectionHeader("snowflake", title: "Fresh Powder", subtitle: "This week's snowfall", tint: .blue)
        IllustratedSectionHeader("flame.fill", title: "Trending", tint: .orange)
    }
    .padding()
}

#Preview("Emoji Scenes") {
    VStack(spacing: 20) {
        EmojiScene(["🏔️", "🇨🇭", "☀️", "🏔️"])
        EmojiScene(["🎪", "🧸", "🎨", "🌈", "⭐"])
        EmojiScene(["🍽️", "🧀", "🫕", "🍫"])
    }
}
