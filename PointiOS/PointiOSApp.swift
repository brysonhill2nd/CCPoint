// PointiOSApp.swift - Simplified without LocationManager
import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct PointiOSApp: App {
    // Use the App Delegate to handle initialization of Firebase and other services
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // State objects
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var storeManager = StoreManager.shared

    var body: some Scene {
        WindowGroup {
            // Swiss Minimalist design (default)
            // Change to OldContentView() to revert to the original design
            ContentView()
                .environmentObject(watchConnectivity)
                .environmentObject(storeManager)
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

        // Initialize StoreKit for in-app purchases
        _ = StoreManager.shared
        print("💳 StoreKit initialized")

        return true
    }

    // Handle Google Sign-In URL callback
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
