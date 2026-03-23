import SwiftUI

/// Inline anchor pills displayed in the Plan sub-view config section.
/// Each pill shows: category emoji + title + time range + optional neighbourhood + delete button.
///
/// Layout per the v5 spec:
/// ```
/// [ 🍴 Brunch at Khouris · 11:15–12:45 · Seefeld  ✕ ]
/// [ 🎉 Noah's birthday · 14:00–16:00               ✕ ]
/// [ + Add another ]
/// ```
struct AnchorPillRowView: View {
    @Environment(AppState.self) private var appState

    let anchors: [AnchorEvent]
    let onAdd: () -> Void
    let onEdit: (AnchorEvent) -> Void
    let onDelete: (AnchorEvent) -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Zurich")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(anchors) { anchor in
                anchorPill(anchor)
            }

            // "Add another" button
            if anchors.count < 5 {
                Button(action: onAdd) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text(anchors.isEmpty
                             ? appState.localized(en: "Got plans?", de: "Schon was vor?")
                             : appState.localized(en: "Add another", de: "Weitere hinzufügen"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.znTerracotta)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        Capsule()
                            .stroke(Color.znTerracotta.opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Single Anchor Pill

    private func anchorPill(_ anchor: AnchorEvent) -> some View {
        Button {
            onEdit(anchor)
        } label: {
            HStack(spacing: 6) {
                // Category emoji
                Text(anchor.category.emoji)
                    .font(.system(size: 13))

                // Title (truncated)
                Text(anchor.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.znInk)
                    .lineLimit(1)

                Text("·")
                    .foregroundStyle(Color.znMuted)

                // Time range
                Text(timeRange(anchor))
                    .font(.znMono)
                    .foregroundStyle(Color.znNavy)

                // Neighbourhood (if present)
                if let neighbourhood = anchor.neighbourhood, !neighbourhood.isEmpty {
                    Text("·")
                        .foregroundStyle(Color.znMuted)
                    Text(neighbourhood)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.znMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Delete button
                Button {
                    onDelete(anchor)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.znMuted)
                        .frame(width: 18, height: 18)
                        .background(Color.znNeutralTagBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.znNavy.opacity(0.06))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.znNavy.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func timeRange(_ anchor: AnchorEvent) -> String {
        let start = Self.timeFormatter.string(from: anchor.startTime)
        let end = Self.timeFormatter.string(from: anchor.endTime)
        return "\(start)–\(end)"
    }
}
