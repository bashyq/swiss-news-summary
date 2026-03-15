import SwiftUI

@main
struct TodayInSwitzerlandApp: App {
    @State private var appState = AppState()
    @State private var locationManager = LocationManager()
    @State private var toastManager = ToastManager()
    @State private var reminderManager = ReminderManager()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(locationManager)
                .environment(toastManager)
                .environment(reminderManager)
                .preferredColorScheme(appState.theme.colorScheme)
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
                .task {
                    reminderManager.cleanupPastReminders()
                    AnchorStore.shared.purgeIfNewDay()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        AnchorStore.shared.purgeIfNewDay()
                    }
                }
        }
    }
}
