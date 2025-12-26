//
//  ContentView.swift
//  PointiOS
//
//  Swiss Minimalist Main Content View with Tab Navigation
//

import SwiftUI
import CloudKit
import AuthenticationServices

struct ContentView: View {
    @State private var selectedTab = 0 // Start on Activity tab
    @State private var hasScheduledInitialSync = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var appData = AppData()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var authManager = AuthenticationManager.shared

    private var colors: SwissAdaptiveColors {
        SwissAdaptiveColors(isDarkMode: appData.isDarkMode)
    }

    var body: some View {
        ZStack {
            // Background - adaptive to dark mode
            colors.background.ignoresSafeArea()

            // Check authentication state
            switch authManager.authState {
            case .unauthenticated:
                SwissAuthenticationView()
                    .environment(\.isDarkMode, appData.isDarkMode)
                    .onAppear {
                        print("🔍 Showing AuthenticationView - User is unauthenticated")
                    }

            case .authenticating:
                SwissLoadingView()
                    .environment(\.isDarkMode, appData.isDarkMode)
                    .onAppear {
                        print("🔍 Showing LoadingView - Authentication in progress")
                    }

            case .authenticated(let user):
                // Main content
                VStack(spacing: 0) {
                    // Tab content
                    Group {
                        switch selectedTab {
                        case 0:
                            SwissDashboardView()
                                .environmentObject(appData)
                                .environmentObject(watchConnectivity)
                                .environmentObject(cloudKitManager)
                                .environmentObject(authManager)
                        case 1:
                            SwissStatisticsView()
                                .environmentObject(appData)
                                .environmentObject(watchConnectivity)
                                .environmentObject(cloudKitManager)
                                .environmentObject(authManager)
                        case 2:
                            SwissProfileView()
                                .environmentObject(appData)
                                .environmentObject(watchConnectivity)
                                .environmentObject(cloudKitManager)
                                .environmentObject(authManager)
                        default:
                            SwissDashboardView()
                                .environmentObject(appData)
                                .environmentObject(watchConnectivity)
                                .environmentObject(cloudKitManager)
                                .environmentObject(authManager)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Swiss Tab Bar
                    SwissMainTabBar(selectedTab: $selectedTab)
                }
                .environment(\.isDarkMode, appData.isDarkMode)
                .environment(\.adaptiveColors, SwissAdaptiveColors(isDarkMode: appData.isDarkMode))
                .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                    SwissOnboardingView()
                        .environmentObject(watchConnectivity)
                }
                .onAppear {
                    print("🔍 Main content appeared - User: \(user.displayName)")
                    scheduleInitialSyncIfNeeded(for: user)
                }

            case .error(let message):
                SwissErrorView(message: message) {
                    authManager.checkAuthStatus()
                }
                .environment(\.isDarkMode, appData.isDarkMode)
                .environment(\.adaptiveColors, SwissAdaptiveColors(isDarkMode: appData.isDarkMode))
                .onAppear {
                    print("🔍 Showing ErrorView - Error: \(message)")
                }
            }
        }
        .preferredColorScheme(appData.isDarkMode ? .dark : .light)
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

// MARK: - Swiss Main Tab Bar
struct SwissMainTabBar: View {
    @Environment(\.isDarkMode) var isDarkMode
    @Binding var selectedTab: Int

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        HStack(spacing: 0) {
            SwissMainTabBarButton(
                icon: "square.grid.2x2",
                title: "Activity",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )

            SwissMainTabBarButton(
                icon: "chart.bar",
                title: "Stats",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )

            SwissMainTabBarButton(
                icon: "person",
                title: "Profile",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
        }
        .background(colors.background)
        .overlay(
            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct SwissMainTabBarButton: View {
    @Environment(\.isDarkMode) var isDarkMode
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? colors.primary : colors.textSecondary)

                Text(title)
                    .font(SwissTypography.monoLabel(9))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(isSelected ? colors.primary : colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(
                Rectangle()
                    .fill(isSelected ? colors.primary : Color.clear)
                    .frame(height: 2),
                alignment: .top
            )
        }
    }
}

// MARK: - Swiss Authentication View
struct SwissAuthenticationView: View {
    @Environment(\.isDarkMode) var isDarkMode
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingEmailAuth = false

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        VStack(spacing: 0) {
            Spacer()

            // Logo/Brand
            VStack(spacing: 16) {
                Text("Point")
                    .font(.system(size: 64, weight: .bold))
                    .tracking(-3)
                    .foregroundColor(colors.textPrimary)

                Text("Track. Analyze. Improve.")
                    .font(SwissTypography.monoLabel(12))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            // Sign In Options
            VStack(spacing: 16) {
                // Apple Sign In - Using native SignInWithAppleButton
                SignInWithAppleButton(
                    .continue,
                    onRequest: { request in
                        authManager.handleSignInWithAppleRequest(request)
                    },
                    onCompletion: { result in
                        authManager.handleSignInWithAppleCompletion(result)
                    }
                )
                .signInWithAppleButtonStyle(isDarkMode ? .white : .black)
                .frame(height: 56)

                // Google Sign In
                Button(action: {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                }) {
                    HStack(spacing: 12) {
                        GoogleLogo()
                        Text("Continue with Google")
                            .foregroundColor(colors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle()
                            .stroke(colors.border, lineWidth: 1)
                    )
                }
                .disabled(authManager.authState == .authenticating)

                Button(action: {
                    showingEmailAuth = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                            .foregroundColor(colors.primary)
                        Text("Sign up with Email")
                            .foregroundColor(colors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        Rectangle()
                            .stroke(colors.border, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)

            // Footer
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(colors.textSecondary)

                HStack(spacing: 4) {
                    Button("Terms") {}
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.primary)
                        .underline()

                    Text("and")
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.textSecondary)

                    Button("Privacy Policy") {}
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.primary)
                        .underline()
                }
            }
            .padding(.bottom, 32)
        }
        .background(colors.background)
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView(isSignUp: true)
                .environmentObject(authManager)
        }
    }
}

// MARK: - Swiss Loading View
struct SwissLoadingView: View {
    @Environment(\.isDarkMode) var isDarkMode
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        VStack(spacing: 32) {
            Text("Point")
                .font(.system(size: 48, weight: .bold))
                .tracking(-2)
                .foregroundColor(colors.textPrimary)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index < dotCount ? colors.primary : colors.borderSubtle)
                        .frame(width: 8, height: 8)
                }
            }

            Text("Loading")
                .font(SwissTypography.monoLabel(11))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundColor(colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

// MARK: - Swiss Error View
struct SwissErrorView: View {
    @Environment(\.isDarkMode) var isDarkMode
    let message: String
    let retry: () -> Void

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        VStack(spacing: 32) {
            // Error Icon
            Text("!")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(SwissColors.white)
                .frame(width: 80, height: 80)
                .background(SwissColors.red)

            // Title
            Text("Something Went Wrong")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .foregroundColor(colors.textPrimary)

            // Message
            Text(message)
                .font(SwissTypography.monoLabel(12))
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)

            // Retry Button
            Button(action: retry) {
                Text("Try Again")
            }
            .buttonStyle(SwissPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
    }
}

#Preview {
    ContentView()
}
