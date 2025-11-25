import SwiftUI

@main
struct ClaudePointApp: App {
    @StateObject private var gameSettings = GameSettings()
    @StateObject private var tennisSettings = TennisSettings()
    @StateObject private var padelSettings = PadelSettings()
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var historyManager = HistoryManager()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameSettings)
                .environmentObject(tennisSettings)
                .environmentObject(padelSettings)
                .environmentObject(navigationManager)
                .environmentObject(historyManager)
                .environmentObject(watchConnectivity)
                .onAppear {
                    // Check for any pending Watch data when the app launches (in background)
                    DispatchQueue.global(qos: .utility).async {
                        watchConnectivity.checkForPendingData()
                    }
                }
        }
    }
}
