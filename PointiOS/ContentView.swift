//
//  ContentView.swift
//  PointiOS
//
//  Main content view with Firebase authentication
//

import SwiftUI
import CloudKit

struct ContentView: View {
    @State private var selectedTab = 1 // Start on Games tab
    @State private var hasScheduledInitialSync = false
    @StateObject private var appData = AppData()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var authManager = AuthenticationManager.shared

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground).ignoresSafeArea()
            
            // Check authentication state
            switch authManager.authState {
            case .unauthenticated:
                AuthenticationView()
                    .onAppear {
                        print("🔍 Showing AuthenticationView - User is unauthenticated")
                    }
                
            case .authenticating:
                LoadingView()
                    .onAppear {
                        print("🔍 Showing LoadingView - Authentication in progress")
                    }
                
            case .authenticated(let user):
                // Main content
                VStack(spacing: 0) {
                    // CloudKit Status Bar (optional - for debugging)
                    if cloudKitManager.syncStatus != .idle {
                        CloudKitStatusBar()
                            .environmentObject(cloudKitManager)
                            .transition(.move(edge: .top))
                    }
                    
                    // Tab content
                    Group {
                        switch selectedTab {
                        case 0:
                            ProfileView()
                                .environmentObject(appData)
                                .environmentObject(watchConnectivity)
                                .environmentObject(cloudKitManager)
                                .environmentObject(authManager)
                        case 1:
                            GameView()
                                .environmentObject(appData)
                                .environmentObject(watchConnectivity)
                                .environmentObject(cloudKitManager)
                                .environmentObject(authManager)
                        case 2:
                            SettingsView()
                                .environmentObject(appData)
                                .environmentObject(watchConnectivity)
                                .environmentObject(cloudKitManager)
                                .environmentObject(authManager)
                        default:
                            GameView()
                                .environmentObject(appData)
                                .environmentObject(watchConnectivity)
                                .environmentObject(cloudKitManager)
                                .environmentObject(authManager)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Custom floating tab bar
                    FloatingTabBar(selectedTab: $selectedTab)
                }
                .onAppear {
                    print("🔍 Main content appeared - User: \(user.displayName)")
                    scheduleInitialSyncIfNeeded(for: user)
                }
                
            case .error(let message):
                ErrorView(message: message) {
                    authManager.checkAuthStatus()
                }
                .onAppear {
                    print("🔍 Showing ErrorView - Error: \(message)")
                }
            }
        }
        .preferredColorScheme(appData.userSettings.appearanceMode.colorScheme)
    }
    
    private func scheduleInitialSyncIfNeeded(for user: PointUser) {
        guard !hasScheduledInitialSync else { return }
        hasScheduledInitialSync = true
        
        Task {
            async let subscriptionTask = cloudKitManager.setupSubscriptionsIfNeeded(userId: user.id)
            async let profileTask = authManager.syncUserProfileWithCloudKit()
            async let gamesTask = watchConnectivity.refreshFromCloudIfStale()
            _ = await (subscriptionTask, profileTask, gamesTask)
        }
    }
}

// Loading View
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Error View
struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: retry) {
                    Text("Try Again")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.accentColor)
                        .cornerRadius(25)
                }
                .padding(.top, 20)
            }
        }
    }
}

// CloudKit Status Bar Component
struct CloudKitStatusBar: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    var body: some View {
        HStack {
            switch cloudKitManager.syncStatus {
            case .idle:
                EmptyView()
            case .syncing:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                    Text("Syncing to iCloud...")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            case .success:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.icloud.fill")
                        .foregroundColor(.green)
                    Text("Synced to iCloud")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .onAppear {
                    // Hide success message after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        cloudKitManager.syncStatus = .idle
                    }
                }
            case .error(let message):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.icloud.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(20)
        .padding(.top, 10)
    }
}

// Floating Tab Bar
struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            TabBarButton(
                icon: "figure.pickleball",
                title: "Games",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            TabBarButton(
                icon: "gearshape.fill",
                title: "Settings",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
                .overlay(
                    Capsule()
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
