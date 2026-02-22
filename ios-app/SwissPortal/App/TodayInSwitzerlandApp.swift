import SwiftUI

@main
struct TodayInSwitzerlandApp: App {
    @State private var appState = AppState()
    @State private var locationManager = LocationManager()
    @State private var toastManager = ToastManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(locationManager)
                .environment(toastManager)
                .preferredColorScheme(appState.theme.colorScheme)
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
        }
    }
}
