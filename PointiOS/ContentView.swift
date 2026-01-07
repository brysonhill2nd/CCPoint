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

// MARK: - Swiss Authentication View (Legacy)
struct SwissAuthenticationViewLegacy: View {
    @Environment(\.isDarkMode) var isDarkMode
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingEmailAuth = false
    @State private var isEmailSignUp = true

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        VStack(spacing: 0) {
            Spacer()

            // Logo/Brand
            VStack(spacing: 16) {
                PointWordmark(size: 64, textColor: colors.textPrimary)

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
                    isEmailSignUp = true
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

                Button(action: {
                    isEmailSignUp = false
                    showingEmailAuth = true
                }) {
                    Text("Log in")
                        .font(SwissTypography.monoLabel(12))
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .fontWeight(.bold)
                        .foregroundColor(SwissColors.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(SwissColors.green)
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
                    Link("Terms", destination: URL(string: "https://pointapp.app/terms-of-service")!)
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.primary)
                        .underline()

                    Text("and")
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.textSecondary)

                    Link("Privacy Policy", destination: URL(string: "https://pointapp.app/privacy-policy")!)
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.primary)
                        .underline()
                }
            }
            .padding(.bottom, 32)
        }
        .background(colors.background)
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView(isSignUp: isEmailSignUp)
                .environmentObject(authManager)
        }
    }
}

// MARK: - Swiss Authentication View (Luxury)
struct SwissAuthenticationView: View {
    @Environment(\.isDarkMode) var isDarkMode
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingEmailAuth = false
    @State private var isEmailSignUp = false

    private let accentGreen = Color(red: 0.431, green: 0.918, blue: 0.31)
    private let topDark = Color(red: 0.043, green: 0.059, blue: 0.051)
    private let bottomDark = Color(red: 0.082, green: 0.102, blue: 0.090)

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        ZStack {
            LinearGradient(
                colors: [topDark, bottomDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TennisCourtOverlay()
                .allowsHitTesting(false)

            RadialGradient(
                gradient: Gradient(colors: [accentGreen.opacity(0.08), .clear]),
                center: .bottom,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                headerSection(colors: colors)
                    .padding(.top, 48)
                    .padding(.horizontal, 28)

                Spacer(minLength: 16)

                deviceStack
                    .padding(.horizontal, 10)

                Spacer(minLength: 16)

                authSection(colors: colors)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView(isSignUp: isEmailSignUp)
                .environmentObject(authManager)
        }
    }

    private func headerSection(colors: SwissAdaptiveColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("trans-dark")
                .resizable()
                .scaledToFit()
                .frame(height: 26)
            Text("WELCOME TO POINT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(3)
                .foregroundColor(colors.textSecondary.opacity(0.5))

            Text("Never forget the score.")
                .font(.system(size: 48, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(colors.textPrimary)
                .lineSpacing(-5)

            HStack(spacing: 10) {
                Rectangle()
                    .fill(accentGreen)
                    .frame(width: 32, height: 2)

                Text("Play. Track. Win.")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(accentGreen)
            }
        }
    }

    private var deviceStack: some View {
        ZStack {
            DeviceMockupView(
                frameImageName: "iphone_17_pro_max",
                screenImageName: "point_iphone_screen",
                cornerRadius: 48
            )
            .rotation3DEffect(.degrees(-15), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(5), axis: (x: 1, y: 0, z: 0))
            .offset(x: 50, y: 20)

            DeviceMockupView(
                frameImageName: "watch_ultra",
                screenImageName: "point_watch_screen",
                cornerRadius: 34
            )
            .rotation3DEffect(.degrees(18), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(10), axis: (x: 1, y: 0, z: 0))
            .offset(x: -70, y: -10)
            .zIndex(1)
        }
        .shadow(color: .black.opacity(0.8), radius: 40, x: 20, y: 30)
    }

    private func authSection(colors: SwissAdaptiveColors) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                AppleIconButton(
                    onRequest: { request in
                        authManager.handleSignInWithAppleRequest(request)
                    },
                    onCompletion: { result in
                        authManager.handleSignInWithAppleCompletion(result)
                    }
                )
                SocialIconButton(icon: "G Logo", isAsset: true) {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                }
                SocialIconButton(icon: "envelope.fill") {
                    isEmailSignUp = true
                    showingEmailAuth = true
                }
            }

            HStack(spacing: 12) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                Text("OR")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(colors.textSecondary.opacity(0.7))
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
            }

            Button(action: {
                isEmailSignUp = false
                showingEmailAuth = true
            }) {
                HStack(spacing: 8) {
                    Text("Log In with Email")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colors.textPrimary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }

            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 11))
                    .foregroundColor(colors.textSecondary)

                HStack(spacing: 8) {
                    Link("Terms of Service", destination: URL(string: "https://pointapp.app/terms-of-service")!)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accentGreen)

                    Link("Privacy Policy", destination: URL(string: "https://pointapp.app/privacy-policy")!)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accentGreen)
                }
            }
        }
    }
}

private struct SocialIconButton: View {
    let icon: String
    var isAsset: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: 56, height: 56)

                if isAsset, let image = UIImage(named: icon) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                } else if isAsset {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AppleIconButton: View {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .frame(width: 56, height: 56)

            Image(systemName: "applelogo")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.black)

            SignInWithAppleButton(
                .continue,
                onRequest: onRequest,
                onCompletion: onCompletion
            )
            .signInWithAppleButtonStyle(.black)
            .frame(width: 56, height: 56)
            .opacity(0.02)
        }
    }
}

private struct DeviceMockupView: View {
    let frameImageName: String
    let screenImageName: String
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            if let screen = UIImage(named: screenImageName) {
                Image(uiImage: screen)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }

            if let frame = UIImage(named: frameImageName) {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius + 6)
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
            }
        }
    }
}

private struct TennisCourtOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let courtHeight = size.height * 0.42
                let courtWidth = size.width * 0.82
                let originX = (size.width - courtWidth) / 2
                let originY = size.height * 0.52
                let rect = CGRect(x: originX, y: originY, width: courtWidth, height: courtHeight)
                let lineColor = Color.white.opacity(0.1)

                context.stroke(Path(rect), with: .color(lineColor), lineWidth: 1)

                // Net line
                let netY = rect.midY
                var netPath = Path()
                netPath.move(to: CGPoint(x: rect.minX, y: netY))
                netPath.addLine(to: CGPoint(x: rect.maxX, y: netY))
                context.stroke(netPath, with: .color(lineColor), lineWidth: 1)

                // Service line
                let serviceLineY = rect.minY + rect.height * 0.25
                var servicePath = Path()
                servicePath.move(to: CGPoint(x: rect.minX, y: serviceLineY))
                servicePath.addLine(to: CGPoint(x: rect.maxX, y: serviceLineY))
                context.stroke(servicePath, with: .color(lineColor), lineWidth: 1)

                // Center service line
                var centerPath = Path()
                centerPath.move(to: CGPoint(x: rect.midX, y: rect.minY))
                centerPath.addLine(to: CGPoint(x: rect.midX, y: netY))
                context.stroke(centerPath, with: .color(lineColor), lineWidth: 1)

                // Center marks
                var centerMarks = Path()
                centerMarks.move(to: CGPoint(x: rect.midX - 12, y: rect.minY))
                centerMarks.addLine(to: CGPoint(x: rect.midX + 12, y: rect.minY))
                centerMarks.move(to: CGPoint(x: rect.midX - 12, y: rect.maxY))
                centerMarks.addLine(to: CGPoint(x: rect.midX + 12, y: rect.maxY))
                context.stroke(centerMarks, with: .color(lineColor), lineWidth: 1)
            }
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
            PointWordmark(size: 48, textColor: colors.textPrimary)

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
