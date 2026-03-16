import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @Binding var path: NavigationPath

    var weather: Weather?
    var sunshineDestinations: [SunshineDestination]?
    var snowDestinations: [SnowDestination]?
    var cityEvents: [CityEvent]?
    var upcomingEventCount: Int = 0

    @State private var nudge: Nudge?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                discoverHero

                VStack(spacing: 16) {
                    // Smart nudge card
                    if let nudge {
                        SmartNudgeCard(nudge: nudge) {
                            switch nudge.type {
                            case .sunshineEscape:
                                path.append(DiscoverRoute.sunshine)
                            case .freshSnow:
                                path.append(DiscoverRoute.snow)
                            case .upcomingEvent:
                                path.append(DiscoverRoute.events)
                            }
                        }
                    }

                    // Hero cards
                    Button {
                        ZnuniEvent.discoverSunshineOpened()
                        path.append(DiscoverRoute.sunshine)
                    } label: {
                        SunshineHeroCard()
                    }
                    .buttonStyle(.plain)

                    Button {
                        ZnuniEvent.discoverSnowOpened()
                        path.append(DiscoverRoute.snow)
                    } label: {
                        SnowHeroCard()
                    }
                    .buttonStyle(.plain)

                    Button { path.append(DiscoverRoute.events) } label: {
                        EventsHeroCard(upcomingCount: upcomingEventCount)
                    }
                    .buttonStyle(.plain)

                    // Explore nearby
                    ExploreNearbySection(path: $path)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.znCream)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            nudge = NudgeEngine.evaluate(
                weather: weather,
                sunshineDestinations: sunshineDestinations,
                snowDestinations: snowDestinations,
                events: cityEvents,
                language: appState.language
            )
        }
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
