import SwiftUI

/// A gradient hero banner with title text overlaid and decorative SF Symbols.
/// Replaces both the navigation title and header banner in one compact element.
/// Optionally accepts trailing toolbar content (buttons) displayed on the right side.
struct HeroBanner<Trailing: View>: View {
    let style: Style
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(style: Style, title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.style = style
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    enum Style {
        case news
        case activities
        case lunch
        case sunshine
        case snow
        case explore

        var gradient: [Color] {
            // Znuni: uniform deep navy for all hero headers
            return [Color.znNavy, Color.znNavy.opacity(0.92)]
        }

        /// Large background symbol (decorative)
        var backgroundSymbol: String {
            switch self {
            case .news: return "newspaper.fill"
            case .activities: return "figure.play"
            case .lunch: return "fork.knife"
            case .sunshine: return "sun.max.fill"
            case .snow: return "snowflake"
            case .explore: return "map.fill"
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
            case .explore: return ["mappin.circle.fill", "binoculars.fill", "flag.fill"]
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

            // Terracotta radial glow accent
            RadialGradient(
                colors: [Color.znTerracotta.opacity(0.15), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 120
            )

            // Large background symbol — faded, offset right
            Image(systemName: style.backgroundSymbol)
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 110, y: 0)
                .rotationEffect(.degrees(-10))

            // Scattered small symbols
            scatteredSymbols

            // Title + trailing content overlaid
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Playfair", size: 20).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.znEyebrow)
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.4)
                            .lineLimit(1)
                    }
                }
                Spacer()
                trailing
                    .foregroundStyle(.white)
                    .font(.body)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }

    // MARK: - Scattered Symbols

    private var scatteredSymbols: some View {
        let positions: [(x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double, opacity: Double)] = [
            (x: -40, y: -8, size: 12, rotation: -15, opacity: 0.15),
            (x: 40, y: 10, size: 10, rotation: 20, opacity: 0.12),
            (x: 80, y: -10, size: 11, rotation: -8, opacity: 0.14),
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

// MARK: - Convenience init (no trailing buttons → shows Swiss cross)

extension HeroBanner where Trailing == SwissCrossBadge {
    init(style: Style, title: String, subtitle: String? = nil) {
        self.style = style
        self.title = title
        self.subtitle = subtitle
        self.trailing = SwissCrossBadge()
    }
}

/// Small Swiss cross badge used as default trailing content in HeroBanner.
struct SwissCrossBadge: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(.white)
                .frame(width: 12, height: 4)
            RoundedRectangle(cornerRadius: 2)
                .fill(.white)
                .frame(width: 4, height: 12)
        }
        .opacity(0.4)
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
        HeroBanner(style: .news, title: "Today in Zürich") {
            Image(systemName: "square.and.arrow.up")
        }
        HeroBanner(style: .activities, title: "What to do?") {
            HStack(spacing: 12) {
                Image(systemName: "map")
                Image(systemName: "plus")
            }
        }
        HeroBanner(style: .lunch, title: "Lunch")
        HeroBanner(style: .sunshine, title: "Weekend Sunshine")
        HeroBanner(style: .snow, title: "Snow Report")
    }
    .padding()
}

#Preview("Section Headers") {
    VStack(spacing: 16) {
        IllustratedSectionHeader("sun.max.fill", title: "Weekend Sunshine", subtitle: "Fri–Sun forecast", tint: .znTerracotta)
        IllustratedSectionHeader("snowflake", title: "Fresh Powder", subtitle: "This week's snowfall", tint: .znNavy)
        IllustratedSectionHeader("flame.fill", title: "Trending", tint: .znTerracotta)
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
