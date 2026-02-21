import SwiftUI

@main
struct TodayInSwitzerlandApp: App {
    @State private var appState = AppState()
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(locationManager)
                .preferredColorScheme(appState.theme.colorScheme)
        }
    }
}
