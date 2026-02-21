import SwiftUI

/// Reusable filter chip button used in filter bars
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var icon: String?
    var count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? .white.opacity(0.3) : .secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.purple : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Horizontal scrollable filter bar
struct FilterBar<Filter: Hashable>: View {
    let filters: [Filter]
    let selected: Filter
    let label: (Filter) -> String
    var icon: ((Filter) -> String?)? = nil
    var count: ((Filter) -> Int?)? = nil
    let onSelect: (Filter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(
                        label: label(filter),
                        isSelected: selected == filter,
                        icon: icon?(filter),
                        count: count?(filter),
                        action: { onSelect(filter) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}
