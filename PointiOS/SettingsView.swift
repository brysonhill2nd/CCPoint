//
//  SettingsView.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/20/25.
//

// SettingsView.swift
import SwiftUI
import Lucide

struct SettingsView: View {
    @State private var showingSportSettings = false
    @State private var selectedSport: String = ""
    @State private var showingSignOutAlert = false
    @EnvironmentObject var appData: AppData
    @StateObject private var userHealthManager = CompleteUserHealthManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    gameRulesSection
                    appSettingsSection
                    dataPrivacySection
                    supportSection
                    accountSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSportSettings) {
                SportSettingsSheet(sport: selectedSport)
                    .environmentObject(appData)
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            Text("⚙️")
                .font(.system(size: 60))

            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Customize your experience")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    private var gameRulesSection: some View {
        SettingsCard(title: "Game Rules") {
            VStack(spacing: 0) {
                SportSettingsRow(
                    icon: "🥒",
                    sport: "Pickleball",
                    action: {
                        selectedSport = "pickleball"
                        showingSportSettings = true
                    }
                )

                Divider().background(Color.gray.opacity(0.3))

                SportSettingsRow(
                    icon: "🎾",
                    sport: "Tennis",
                    action: {
                        selectedSport = "tennis"
                        showingSportSettings = true
                    }
                )

                Divider().background(Color.gray.opacity(0.3))

                SportSettingsRow(
                    icon: "🏓",
                    sport: "Padel",
                    action: {
                        selectedSport = "padel"
                        showingSportSettings = true
                    }
                )
            }
        }
    }

    private var appSettingsSection: some View {
        SettingsCard(title: "App Settings") {
            VStack(spacing: 16) {
                appearancePicker

                Divider().background(Color.gray.opacity(0.3))

                ToggleRow(
                    title: "Haptic Feedback",
                    isOn: $appData.hapticFeedback
                )

                ToggleRow(
                    title: "Sound Effects",
                    isOn: $appData.soundEffects
                )
            }
        }
    }

    private var appearancePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.headline)
                .foregroundColor(.primary)

            let modes: [AppearanceMode] = [.light, .dark, .system]
            HStack(spacing: 12) {
                ForEach(modes, id: \.self) { mode in
                    Button(action: {
                        appData.userSettings.appearanceMode = mode
                        appData.saveSettings()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode == .light ? "sun.max.fill" : mode == .dark ? "moon.fill" : "circle.lefthalf.filled")
                                .font(.system(size: 24))
                                .foregroundColor(appData.userSettings.appearanceMode == mode ? .accentColor : .secondary)

                            Text(mode.rawValue)
                                .font(.caption)
                                .foregroundColor(appData.userSettings.appearanceMode == mode ? .accentColor : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(appData.userSettings.appearanceMode == mode ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                        )
                    }
                }
            }
        }
    }

    private var dataPrivacySection: some View {
        SettingsCard(title: "Data & Privacy") {
            VStack(spacing: 0) {
                ActionRow(title: "Export Game Data", color: .blue)
                Divider().background(Color.gray.opacity(0.3))
                HStack {
                    Text("Sync with DUPR")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Coming Soon")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.vertical, 12)
                .opacity(0.5)
                Divider().background(Color.gray.opacity(0.3))
                ActionRow(title: "Clear All Data", color: .red)
            }
        }
    }

    private var supportSection: some View {
        SettingsCard(title: "Support") {
            VStack(spacing: 0) {
                ActionRow(title: "Help Center", color: .white)
                Divider().background(Color.gray.opacity(0.3))
                ActionRow(title: "Report a Problem", color: .white)
            }
        }
    }

    private var accountSection: some View {
        SettingsCard(title: "Account") {
            VStack(spacing: 0) {
                if let user = AuthenticationManager.shared.currentUser {
                    userInfoRow(user: user)
                    Divider().background(Color.gray.opacity(0.3))
                }

                if !userHealthManager.healthKitAuthorized {
                    healthKitAuthButton
                    Divider().background(Color.gray.opacity(0.3))
                }

                signOutButton
            }
        }
    }

    private func userInfoRow(user: PointUser) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let enhancedUser = userHealthManager.currentUser {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(enhancedUser.totalCaloriesBurned)) cal")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(enhancedUser.totalActiveMinutes) min")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }

    private var healthKitAuthButton: some View {
        Button(action: {
            Task {
                try? await EnhancedHealthKitManager.shared.requestAuthorization()
            }
        }) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Enable Health Tracking")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
        }
    }

    private var signOutButton: some View {
        Button(action: {
            showingSignOutAlert = true
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Text("Sign Out")
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
        }
    }

    private func signOut() {
        // Stop any active workouts
        Task {
            if EnhancedHealthKitManager.shared.isWorkoutActive {
                _ = await EnhancedHealthKitManager.shared.endWorkout()
            }
        }
        
        // Clear local user data cache (but keep for offline access)
        CompleteUserHealthManager.shared.currentUser = nil
        
        // Sign out from Firebase
        AuthenticationManager.shared.signOut()
        
        // The app should automatically navigate to login screen
        // based on AuthenticationManager.shared.authState change
    }
}

// Extension for sign out notification
extension Notification.Name {
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

// Add this to your AppData if not already present
extension AppData {
    var userEmail: String? {
        get { UserDefaults.standard.string(forKey: "userEmail") }
        set { UserDefaults.standard.set(newValue, forKey: "userEmail") }
    }
    
    func clearUserData() {
        // Reset to default values
        self.displayName = "Player"
        // Clear other user-specific properties
        // Add any other properties that need to be cleared
        
        // Clear from UserDefaults
        UserDefaults.standard.removeObject(forKey: "displayName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        // Add other keys that need to be cleared
    }
}
