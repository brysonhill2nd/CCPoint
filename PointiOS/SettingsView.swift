//
//  SettingsView.swift
//  PointiOS
//
//  Swiss Minimalist Settings
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.adaptiveColors) var colors
    @State private var showingSportSettings = false
    @State private var selectedSport: String = ""
    @State private var showingSignOutAlert = false
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @StateObject private var userHealthManager = CompleteUserHealthManager.shared
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingUpgrade = false
    @Environment(\.dismiss) var dismiss
    private let devEmail = "brysonhill2nd@yahoo.com"

    var body: some View {
        VStack(spacing: 0) {
            // Swiss Header
            swissHeader

            ScrollView {
                VStack(spacing: 0) {
                    // Game Rules Section
                    gameRulesSection

                    // App Settings Section
                    appSettingsSection

                    // Watch Fit Section
                    watchFitSection

                    // Data & Privacy Section
                    dataPrivacySection

                    // Account Section
                    accountSection

                    // Pro Section
                    proSection

                    // Support Section
                    supportSection

                    #if DEBUG
                    if isDevUser {
                        devSection
                    }
                    #endif

                    // Version Footer
                    versionFooter

                    Color.clear.frame(height: 100)
                }
            }
        }
        .background(colors.background)
        .sheet(isPresented: $showingSportSettings) {
            SwissSportSettingsSheet(sport: selectedSport)
                .environmentObject(appData)
        }
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
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

    private var isDevUser: Bool {
        AuthenticationManager.shared.currentUser?.email.lowercased() == devEmail
    }

    // MARK: - Header
    private var swissHeader: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(colors.textPrimary)

                    Text("Configure Your Experience")
                        .font(SwissTypography.monoLabel(10))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(SwissColors.gray400)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24))
                        .foregroundColor(colors.textPrimary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
        }
    }

    // MARK: - Game Rules Section
    private var gameRulesSection: some View {
        SwissSettingsSection(title: "Game Rules") {
            VStack(spacing: 0) {
                SwissSportRow(emoji: "🥒", sport: "Pickleball") {
                    selectedSport = "pickleball"
                    showingSportSettings = true
                }

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)

                SwissSportRow(emoji: "🎾", sport: "Tennis") {
                    selectedSport = "tennis"
                    showingSportSettings = true
                }

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)

                SwissSportRow(emoji: "🏓", sport: "Padel") {
                    selectedSport = "padel"
                    showingSportSettings = true
                }
            }
        }
    }

    // MARK: - App Settings Section
    private var appSettingsSection: some View {
        SwissSettingsSection(title: "App Settings") {
            VStack(spacing: 0) {
                // Dark Mode Toggle
                SwissToggleRow(title: "Dark Mode", isOn: $appData.isDarkMode)

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)

                // Haptic Feedback
                SwissToggleRow(title: "Haptic Feedback", isOn: $appData.hapticFeedback)

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)

                // Sound Effects
                SwissToggleRow(title: "Sound Effects", isOn: $appData.soundEffects)
            }
        }
    }

    // MARK: - Watch Fit Section
    private var watchFitSection: some View {
        SwissSettingsSection(title: "Watch Fit") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wear Tip")
                    .font(SwissTypography.monoLabel(10))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(colors.textSecondary)

                Text("Wear your Apple Watch on your swinging hand for the most accurate shot detection and insights.")
                    .font(.system(size: 14))
                    .foregroundColor(colors.textSecondary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Data & Privacy Section
    private var dataPrivacySection: some View {
        SwissSettingsSection(title: "Data & Privacy") {
            VStack(spacing: 0) {
                SwissActionRow(title: "Export Game Data", icon: "arrow.down.circle")

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)

                // DUPR Sync - Coming Soon
                HStack {
                    Text("Sync with DUPR")
                        .font(.system(size: 16))
                        .foregroundColor(SwissColors.gray400)

                    Spacer()

                    Text("COMING SOON")
                        .font(SwissTypography.monoLabel(9))
                        .tracking(1)
                        .foregroundColor(SwissColors.gray400)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundColor(SwissColors.gray300)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)

                SwissActionRow(title: "Clear All Data", icon: "trash", isDestructive: true)
            }
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        SwissSettingsSection(title: "Account") {
            VStack(spacing: 0) {
                // User Info
                if let user = AuthenticationManager.shared.currentUser {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(colors.textPrimary)

                            Text(user.email)
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(SwissColors.gray400)
                        }

                        Spacer()

                        if let enhancedUser = userHealthManager.currentUser {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(Int(enhancedUser.totalCaloriesBurned)) CAL")
                                    .font(SwissTypography.monoLabel(10))
                                    .foregroundColor(colors.textPrimary)

                                Text("\(enhancedUser.totalActiveMinutes) MIN")
                                    .font(SwissTypography.monoLabel(10))
                                    .foregroundColor(SwissColors.gray400)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)

                    Rectangle()
                        .fill(colors.borderSubtle)
                        .frame(height: 1)
                }

                // Health Kit
                if !userHealthManager.healthKitAuthorized {
                    Button(action: {
                        Task {
                            try? await EnhancedHealthKitManager.shared.requestAuthorization()
                        }
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(SwissColors.red)

                            Text("Enable Health Tracking")
                                .font(.system(size: 16))
                                .foregroundColor(colors.textPrimary)

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                                .foregroundColor(SwissColors.gray400)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(colors.borderSubtle)
                        .frame(height: 1)
                }

                // Sign Out
                Button(action: { showingSignOutAlert = true }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(SwissColors.red)

                        Text("Sign Out")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(SwissColors.red)

                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Pro Section
    private var proSection: some View {
        SwissSettingsSection(title: "Point Pro") {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(pro.isPro ? "Pro Active" : "Upgrade to Pro")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colors.textPrimary)

                        Spacer()

                        Text(pro.isPro ? "ACTIVE" : "LOCKED")
                            .font(SwissTypography.monoLabel(9))
                            .tracking(1)
                            .foregroundColor(pro.isPro ? SwissColors.green : SwissColors.gray400)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(pro.isPro ? SwissColors.green.opacity(0.1) : SwissColors.gray100)
                    }

                    Text("Unlock full history, premium insights, charts, and cloud sync.")
                        .font(.system(size: 14))
                        .foregroundColor(SwissColors.gray500)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: { showingUpgrade = true }) {
                        Text(pro.isPro ? "Manage Subscription" : "See Pro Benefits")
                            .font(SwissTypography.monoLabel(11))
                            .textCase(.uppercase)
                            .tracking(1)
                            .fontWeight(.bold)
                            .foregroundColor(SwissColors.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SwissColors.green)
                    }
                    .buttonStyle(.plain)

                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
    }

    // MARK: - Support Section
    private var supportSection: some View {
        SwissSettingsSection(title: "Support") {
            VStack(spacing: 0) {
                SwissActionRow(title: "Help Center", icon: "questionmark.circle")

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)

                SwissActionRow(title: "Report a Problem", icon: "exclamationmark.bubble")
            }
        }
    }

    #if DEBUG
    // MARK: - Developer Section (Dev Account Only)
    private var devSection: some View {
        SwissSettingsSection(title: "Developer") {
            VStack(spacing: 0) {
                SwissToggleRow(title: "Pro Override", isOn: Binding(
                    get: { pro.devOverrideEnabled },
                    set: { pro.setDevOverride($0) }
                ))

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)

                SwissActionRow(title: "Load Sample Games", icon: "sparkles") {
                    watchConnectivity.loadSampleGames()
                }
            }
        }
    }
    #endif


    // MARK: - Version Footer
    private var versionFooter: some View {
        VStack(spacing: 8) {
            PointWordmark(size: 20, textColor: SwissColors.gray300)

            Text("VERSION 1.0.0")
                .font(SwissTypography.monoLabel(9))
                .tracking(2)
                .foregroundColor(SwissColors.gray300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Sign Out
    private func signOut() {
        Task {
            if EnhancedHealthKitManager.shared.isWorkoutActive {
                _ = await EnhancedHealthKitManager.shared.endWorkout()
            }
        }

        CompleteUserHealthManager.shared.currentUser = nil
        AuthenticationManager.shared.signOut()
    }
}

// MARK: - Swiss Settings Section
struct SwissSettingsSection<Content: View>: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            Text(title)
                .font(SwissTypography.monoLabel(11))
                .textCase(.uppercase)
                .tracking(1.5)
                .fontWeight(.bold)
                .foregroundColor(colors.textPrimary)
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 16)

            content

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
        }
    }
}

// MARK: - Swiss Sport Row
struct SwissSportRow: View {
    @Environment(\.adaptiveColors) var colors
    let emoji: String
    let sport: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 24))

                Text(sport)
                    .font(.system(size: 16))
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(SwissColors.gray400)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swiss Toggle Row
struct SwissToggleRow: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(colors.textPrimary)

            Spacer()

            // Custom Swiss-style toggle
            Button(action: { isOn.toggle() }) {
                HStack(spacing: 0) {
                    Text("OFF")
                        .font(SwissTypography.monoLabel(9))
                        .tracking(0.5)
                        .foregroundColor(!isOn ? SwissColors.white : SwissColors.gray400)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(!isOn ? SwissColors.black : SwissColors.white)

                    Text("ON")
                        .font(SwissTypography.monoLabel(9))
                        .tracking(0.5)
                        .foregroundColor(isOn ? SwissColors.white : SwissColors.gray400)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isOn ? SwissColors.green : SwissColors.white)
                }
                .overlay(
                    Rectangle()
                        .stroke(SwissColors.gray, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }
}

// MARK: - Swiss Action Row
struct SwissActionRow: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    let icon: String
    var isDestructive: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? SwissColors.red : colors.textPrimary)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(isDestructive ? SwissColors.red : colors.textPrimary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(colors.textSecondary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
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
        self.displayName = "Player"
        UserDefaults.standard.removeObject(forKey: "displayName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppData.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
