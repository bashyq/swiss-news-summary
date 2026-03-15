import SwiftUI

/// Horizontal card for a home activity in bad weather mode.
///
/// 76px gradient thumbnail with emoji + body (label eyebrow, Playfair name,
/// description, tags).
struct HomeActivityCard: View {
    let label: String
    let name: String
    let description: String
    let emoji: String
    let gradient: LinearGradient
    let tags: [String]

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 14) {
            // Gradient thumbnail with emoji
            ZStack {
                gradient
                Text(emoji)
                    .font(.system(size: 28))
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Body
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.znEyebrow)
                    .foregroundStyle(Color.znMuted)

                Text(name)
                    .font(.custom("Playfair", size: 15, relativeTo: .body).weight(.semibold))
                    .foregroundStyle(Color.znInk)
                    .lineLimit(1)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.znBody)
                    .lineLimit(2)
                    .lineSpacing(1)

                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.znNeutralTagText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.znNeutralTagBg)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.znSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(Color.znBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
    }
}

// MARK: - Convenience Initializers

extension HomeActivityCard {
    /// Create from a HomeActivity model
    init(activity: HomeActivity, label: String, gradient: LinearGradient) {
        self.label = label
        self.name = activity.idea
        self.description = activity.reason
        self.emoji = activity.emoji
        self.gradient = gradient
        self.tags = [activity.durationDisplay, activity.ageNote].compactMap { $0 }
    }

    /// Create from a MoviePick model
    init(movie: MoviePick) {
        self.label = movie.label
        self.name = movie.title
        self.description = movie.reason
        self.emoji = movie.emoji
        self.gradient = LinearGradient(
            colors: [Color(red: 0.502, green: 0.565, blue: 0.69), Color(red: 0.251, green: 0.282, blue: 0.471)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        var movieTags: [String] = []
        if let platform = movie.platform { movieTags.append(platform) }
        movieTags.append("\(movie.durationMinutes) min")
        if movie.isFree { movieTags.append("Free") }
        self.tags = movieTags
    }
}

// MARK: - Gradients

extension HomeActivityCard {
    static let bakingGradient = LinearGradient(
        colors: [Color(red: 0.91, green: 0.784, blue: 0.541), Color(red: 0.769, green: 0.604, blue: 0.251)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let craftGradient = LinearGradient(
        colors: [Color(red: 0.784, green: 0.627, blue: 0.565), Color(red: 0.565, green: 0.376, blue: 0.314)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
