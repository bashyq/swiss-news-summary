import SwiftUI

/// Grouped "Quick Info" strip — horizontal segmented cells with icon, label, and value.
/// Used in expanded venue cards (Activity, Restaurant, Plan Slot) for consistent metadata display.
struct VenueQuickInfoRow: View {
    let items: [Item]

    struct Item: Identifiable {
        let id = UUID()
        let icon: String   // SF Symbol or emoji
        let label: String   // Uppercase caption
        let value: String   // Bold value
        var isEmoji: Bool = false
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 3) {
                    if item.isEmoji {
                        Text(item.icon)
                            .font(.system(size: 15))
                    } else {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.znMuted)
                    }
                    Text(item.label.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.3)
                        .foregroundStyle(.znMuted)
                    Text(item.value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.znInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)

                if index < items.count - 1 {
                    Divider()
                        .frame(height: 32)
                        .overlay(Color.znInnerDivider)
                }
            }
        }
        .background(Color.znCream.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.znBorder.opacity(0.5), lineWidth: 1)
        )
    }
}
