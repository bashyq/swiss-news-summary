import SwiftUI

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

#Preview {
    VStack(spacing: 20) {
        EmojiScene(["🏔️", "🇨🇭", "☀️", "🏔️"])
        EmojiScene(["🎪", "🧸", "🎨", "🌈", "⭐"])
        EmojiScene(["🍽️", "🧀", "🫕", "🍫"])
    }
}
