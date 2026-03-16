import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @Binding var path: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                discoverHero

                VStack(spacing: 16) {
                    // Hero cards and browse grid will be added in Tasks 2-3
                    Text(appState.localized(en: "Discover content coming soon", de: "Inhalte folgen"))
                        .font(.body)
                        .foregroundColor(.znMuted)
                        .padding(.top, 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .background(Color.znCream)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hero Banner

    private var discoverHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DISCOVER")
                .font(.znEyebrow)
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.42))

            (
                Text(appState.localized(en: "Discover ", de: "Entdecke "))
                    .font(.bannerTitle)
                    .foregroundStyle(.white)
                + Text(appState.city.displayName)
                    .font(.custom("Playfair", size: 28).italic())
                    .foregroundStyle(.white.opacity(0.65))
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.znNavy
                    .ignoresSafeArea(.container, edges: .top)
                RadialGradient(
                    colors: [Color.znTerracotta.opacity(0.22), .clear],
                    center: UnitPoint(x: 1.2, y: -0.3),
                    startRadius: 0,
                    endRadius: 220
                )
                SkylineIllustration()
                    .frame(width: 200, height: 110)
                    .opacity(0.09)
            }
        }
    }
}
