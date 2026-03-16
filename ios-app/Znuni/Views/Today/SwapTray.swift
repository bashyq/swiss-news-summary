import SwiftUI

/// Horizontal scroll of swap option cards, shown inline below a slot card.
struct SwapTray: View {
    let swaps: [AgendaSlot.SwapOption]
    let onSelect: (AgendaSlot.SwapOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top border
            Rectangle()
                .fill(Color.znTerracotta.opacity(0.1))
                .frame(height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(swaps) { swap in
                        Button {
                            onSelect(swap)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(swap.venueName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.znInk)
                                    .lineLimit(1)

                                Text(swap.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.znBody)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minWidth: 140, alignment: .leading)
                            .background(Color.znSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11)
                                    .stroke(Color.znBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.znTerracotta.opacity(0.04))
        }
    }
}
