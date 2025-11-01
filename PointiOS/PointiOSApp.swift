// PointiOSApp.swift - Simplified without LocationManager
import SwiftUI
import FirebaseCore

@main
struct PointiOSApp: App {
    // Use the App Delegate to handle initialization of Firebase and other services
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // State objects
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchConnectivity)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // CRITICAL: Initialize Firebase FIRST before anything else
        FirebaseApp.configure()
        print("🔥 Firebase initialized")
        
        // NOW it's safe to initialize managers that use Firebase.
        _ = WatchConnectivityManager.shared
        print("📱 iOS: Initializing WatchConnectivity...")
        
        // Initialize Achievement Manager (after Firebase is ready)
        _ = AchievementManager.shared
        print("🏆 iOS: Initializing Achievement System...")
        
        return true
    }
}
