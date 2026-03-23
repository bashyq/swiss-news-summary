import SwiftUI

/// Frosted glass-style button used in hero banner toolbars.
/// Standardized at 34×34pt with 14pt icon across all hero headers.
struct GlassButton: View {
    let systemName: String
    var size: CGFloat = 34
    var iconSize: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// City selector menu styled as a glass button for hero banners.
struct CityMenuButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            ForEach(City.allCases) { city in
                Button {
                    appState.city = city
                } label: {
                    HStack {
                        Text(city.localizedName(language: appState.language))
                        if city == appState.city {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(appState.city.localizedName(language: appState.language))
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.12))
            )
        }
    }
}
