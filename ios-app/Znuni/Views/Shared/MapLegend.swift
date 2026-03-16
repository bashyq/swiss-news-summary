import SwiftUI

/// A single legend entry with a colored circle and label.
struct MapLegendItem {
    let color: Color
    let label: String
}

/// Reusable map legend overlay component.
///
/// Displays a vertical stack of colored circles with caption labels,
/// rendered over an ultra-thin material background.
struct MapLegend: View {
    let items: [MapLegendItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)

                    Text(item.label)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
