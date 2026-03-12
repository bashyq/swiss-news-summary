import SwiftUI

/// Toggle between two sort options
struct SortPicker<S: Hashable>: View {
    let options: [(value: S, label: String, icon: String)]
    @Binding var selected: S

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = option.value
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: option.icon)
                            .font(.caption2)
                        Text(option.label)
                            .font(.caption)
                            .fontWeight(selected == option.value ? .semibold : .regular)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selected == option.value ? Color.brand.opacity(0.15) : .clear)
                    .foregroundStyle(selected == option.value ? .brand : .secondary)
                }
                .buttonStyle(.plain)

                if index < options.count - 1 {
                    Divider()
                        .frame(height: 16)
                }
            }
        }
        .background(Color.znNeutralTagBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// "Show all / Show less" toggle button
struct ShowAllButton: View {
    @Environment(AppState.self) private var appState
    @Binding var showAll: Bool
    let totalCount: Int
    let visibleCount: Int

    var body: some View {
        if totalCount > visibleCount {
            Button {
                withAnimation {
                    showAll.toggle()
                }
            } label: {
                HStack {
                    Text(showAll
                         ? appState.localized(en: "Show less", de: "Weniger anzeigen")
                         : appState.localized(en: "Show all \(totalCount)", de: "Alle \(totalCount) anzeigen"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: showAll ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.znNeutralTagBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
}
