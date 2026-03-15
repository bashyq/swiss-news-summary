import SwiftUI

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
