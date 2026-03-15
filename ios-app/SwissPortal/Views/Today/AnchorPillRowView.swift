import SwiftUI

/// Displays anchor pills in the hero banner header.
///
/// - **Empty state**: Single outlined pill "[ + Got plans today? ]"
/// - **With anchors**: Filled navy pills with label, time, neighbourhood, ✕ remove
/// - **Multiple anchors**: Each on its own row, plus "+ Add another" pill after the last
struct AnchorPillRowView: View {
    @Environment(AppState.self) private var appState

    let anchors: [DayAnchor]
    let onAdd: () -> Void
    let onTap: (DayAnchor) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if anchors.isEmpty {
                // Empty state — outlined pill
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                        Text(appState.localized(
                            en: "Got plans today?",
                            de: "Schon was vor heute?"
                        ))
                        .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.znTerracotta)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.clear)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.znTerracotta.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                // Filled anchor pills
                ForEach(anchors) { anchor in
                    anchorPill(anchor)
                }

                // "+ Add another" pill (up to 3 anchors)
                if anchors.count < 3 {
                    Button(action: onAdd) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .medium))
                            Text(appState.localized(
                                en: "Add another",
                                de: "Weiteren hinzufügen"
                            ))
                            .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Filled Anchor Pill

    private func anchorPill(_ anchor: DayAnchor) -> some View {
        HStack(spacing: 8) {
            // Pill body — tappable for editing
            Button {
                onTap(anchor)
            } label: {
                HStack(spacing: 6) {
                    Text(anchorEmoji(anchor.label))
                        .font(.system(size: 13))

                    Text(truncated(anchor.label, maxLength: 20))
                        .font(.system(size: 12, weight: .medium))

                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))

                    Text(anchor.timeString)
                        .font(.znMono)

                    if let hood = anchor.neighbourhood {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.4))
                        Text(hood)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.znNavy.opacity(0.8))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // ✕ remove button
            Button {
                onRemove(anchor.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 22, height: 22)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func truncated(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength)) + "…"
    }

    /// Simple emoji inference from anchor label keywords.
    private func anchorEmoji(_ label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("birthday") || lower.contains("geburtstag") { return "🎂" }
        if lower.contains("football") || lower.contains("fussball") || lower.contains("soccer") { return "⚽" }
        if lower.contains("doctor") || lower.contains("arzt") || lower.contains("dentist") { return "🏥" }
        if lower.contains("coffee") || lower.contains("kaffee") { return "☕" }
        if lower.contains("school") || lower.contains("schule") { return "🏫" }
        if lower.contains("swim") || lower.contains("schwimm") || lower.contains("pool") { return "🏊" }
        if lower.contains("park") || lower.contains("playground") || lower.contains("spielplatz") { return "🛝" }
        if lower.contains("music") || lower.contains("musik") || lower.contains("concert") { return "🎵" }
        if lower.contains("lunch") || lower.contains("dinner") || lower.contains("essen") { return "🍽️" }
        if lower.contains("meeting") || lower.contains("termin") { return "📅" }
        if lower.contains("flight") || lower.contains("flug") || lower.contains("airport") { return "✈️" }
        if lower.contains("train") || lower.contains("zug") { return "🚂" }
        if lower.contains("play") || lower.contains("spiel") { return "🎮" }
        return "📌"
    }
}
