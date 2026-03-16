import SwiftUI

/// Reusable filter chip button used in filter bars
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var icon: String?
    var count: Int?
    var expandsToFill: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 16, height: 16)
                        .background(isSelected ? .white.opacity(0.25) : Color.znNeutralTagBg)
                        .clipShape(Circle())
                        .contentTransition(.numericText())
                        .animation(.default, value: count)
                }
            }
            .frame(maxWidth: expandsToFill ? .infinity : nil)
            .frame(height: 31)
            .padding(.horizontal, 13)
            .background {
                if isSelected {
                    Color.znNavy
                } else {
                    Color.clear
                }
            }
            .foregroundStyle(isSelected ? .white : Color.znBody)
            .overlay {
                if !isSelected {
                    Capsule().stroke(Color.znBorder, lineWidth: 1)
                }
            }
            .clipShape(Capsule())
            .scaleEffect(isSelected ? AppAnimation.selectedScale : 1.0)
            .animation(AppAnimation.spring, value: isSelected)
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
            HStack(spacing: 7) {
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
