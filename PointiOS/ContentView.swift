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
            async let subscriptionTask: Void = cloudKitManager.setupSubscriptionsIfNeeded(userId: user.id)
            async let profileTask: Void = authManager.syncUserProfileWithCloudKit()
            async let gamesTask: Void = watchConnectivity.refreshFromCloudIfStale()
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
            // Background gradient
            LinearGradient(
                colors: [topDark, bottomDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Content layer
            VStack(spacing: 0) {
                // Header block
                headerSection(colors: colors)
                    .padding(.top, 60)
                    .padding(.horizontal, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 16)

                // Court sits in the gap between header and buttons
                PerspectivePadelCourt()
                    .frame(height: 280)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white.opacity(0.08), location: 0.25),
                                .init(color: .white.opacity(0.35), location: 0.55),
                                .init(color: .white, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                authSection(colors: colors)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .background(
                        Color.black.opacity(0.25)
                            .blur(radius: 12)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingEmailAuth) {
            EmailAuthView(isSignUp: isEmailSignUp)
                .environmentObject(authManager)
        }
    }

    private func headerSection(colors: SwissAdaptiveColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Logo - anchored
            Image("point-logo")
                .resizable()
                .scaledToFit()
                .frame(height: 80)

            // Main headline - the hero
            Text("Never forget the score.")
                .font(.system(size: 36, weight: .regular, design: .serif))
                .italic()
                .tracking(-0.3)
                .foregroundColor(colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            // Tagline - subtle accent (desaturated green)
            HStack(spacing: 8) {
                Rectangle()
                    .fill(accentGreen.opacity(0.85))
                    .frame(width: 24, height: 2)

                Text("Play. Track. Win.")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(accentGreen.opacity(0.85))
            }
            .padding(.top, 4)
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
        VStack(spacing: 12) {
            // Continue with Apple
            SignInWithAppleButton(
                .continue,
                onRequest: { request in
                    authManager.handleSignInWithAppleRequest(request)
                },
                onCompletion: { result in
                    authManager.handleSignInWithAppleCompletion(result)
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)

            // Continue with Google
            ContinueButton(
                title: "Continue with Google",
                icon: "G-Logo",
                isAsset: true,
                style: .outline
            ) {
                Task {
                    await authManager.signInWithGoogle()
                }
            }

            // Continue with Email
            ContinueButton(
                title: "Continue with Email",
                icon: "envelope.fill",
                isAsset: false,
                style: .outline
            ) {
                isEmailSignUp = true
                showingEmailAuth = true
            }

            // Terms - very subtle, footnote style
            VStack(spacing: 4) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 10))
                    .foregroundColor(colors.textSecondary.opacity(0.5))

                HStack(spacing: 6) {
                    Link("Terms", destination: URL(string: "https://pointapp.app/terms-of-service")!)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(colors.textSecondary.opacity(0.7))

                    Text("&")
                        .font(.system(size: 10))
                        .foregroundColor(colors.textSecondary.opacity(0.5))

                    Link("Privacy", destination: URL(string: "https://pointapp.app/privacy-policy")!)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(colors.textSecondary.opacity(0.7))
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Continue Button Components

private enum ContinueButtonStyle {
    case filled
    case outline
}

private struct ContinueButton: View {
    let title: String
    let icon: String
    var isAsset: Bool = false
    var style: ContinueButtonStyle = .outline
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                if isAsset, let image = UIImage(named: icon) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(style == .filled ? .black : .white)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(style == .filled ? .black : .white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Group {
                    if style == .filled {
                        Color.white
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(style == .outline ? 0.2 : 0), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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

private struct PerspectivePadelCourt: View {
    private let lineColor = Color.gray

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            // Court dimensions - perspective trapezoid
            let topWidth: CGFloat = width * 0.40
            let bottomWidth: CGFloat = width * 0.85

            // Vertical positions
            let topY: CGFloat = 0
            let bottomY: CGFloat = height
            let baselineY: CGFloat = height * 0.65

            // Service line: high up, ~25% from top
            let serviceLineY: CGFloat = topY + (bottomY - topY) * 0.30

            // X positions for trapezoid corners
            let centerX = width / 2
            let topLeftX = centerX - topWidth / 2
            let topRightX = centerX + topWidth / 2
            let bottomLeftX = centerX - bottomWidth / 2
            let bottomRightX = centerX + bottomWidth / 2

            // Helper to interpolate X position at a given Y
            func xAtY(_ y: CGFloat, isLeft: Bool) -> CGFloat {
                let t = (y - topY) / (bottomY - topY)
                if isLeft {
                    return topLeftX + t * (bottomLeftX - topLeftX)
                } else {
                    return topRightX + t * (bottomRightX - topRightX)
                }
            }

            // Opacity - darker lines for visibility
            let lineOpacity: Double = 0.12

            // 1. Draw outer boundary (trapezoid) - all 4 sides
            var courtPath = Path()
            courtPath.move(to: CGPoint(x: topLeftX, y: topY))
            courtPath.addLine(to: CGPoint(x: topRightX, y: topY))
            courtPath.addLine(to: CGPoint(x: bottomRightX, y: bottomY))
            courtPath.addLine(to: CGPoint(x: bottomLeftX, y: bottomY))
            courtPath.closeSubpath()
            context.fill(courtPath, with: .color(Color(hex: "1B2A24").opacity(0.22)))
            context.stroke(courtPath, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1)

            // 2. Service line (horizontal, 40% down from top)
            var serviceLinePath = Path()
            serviceLinePath.move(to: CGPoint(x: xAtY(serviceLineY, isLeft: true), y: serviceLineY))
            serviceLinePath.addLine(to: CGPoint(x: xAtY(serviceLineY, isLeft: false), y: serviceLineY))
            context.stroke(serviceLinePath, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1)

            // 3. Center line (ONLY from service line to baseline - NOT above service line)
            var centerLinePath = Path()
            centerLinePath.move(to: CGPoint(x: centerX, y: serviceLineY))
            centerLinePath.addLine(to: CGPoint(x: centerX, y: baselineY))
            context.stroke(centerLinePath, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1)

            // 4. Baseline (near bottom, slightly thicker)
            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: xAtY(baselineY, isLeft: true), y: baselineY))
            baselinePath.addLine(to: CGPoint(x: xAtY(baselineY, isLeft: false), y: baselineY))
            context.stroke(baselinePath, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1.3)
        }
    }
}

private struct PadelCourtIllustration: View {
    var body: some View {
        // 2:1 aspect ratio for padel court (20m x 10m)
        ZStack {
            // Court fill - very subtle
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: "0A1F0A").opacity(0.10))

            // Court lines - white
            PadelCourtShape()
                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
        }
        .aspectRatio(2, contentMode: .fit)
        .rotation3DEffect(.degrees(8), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .mask(
            RadialGradient(
                colors: [.white, .white, .white.opacity(0.3), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 150
            )
        )
    }
}

private struct PadelCourtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let inset: CGFloat = 2
        let courtRect = rect.insetBy(dx: inset, dy: inset)

        // Outer boundary with rounded corners
        path.addRoundedRect(in: courtRect, cornerSize: CGSize(width: 4, height: 4))

        // Center line (net)
        let centerY = rect.midY
        path.move(to: CGPoint(x: courtRect.minX, y: centerY))
        path.addLine(to: CGPoint(x: courtRect.maxX, y: centerY))

        // Service boxes - top half
        let topServiceY = courtRect.minY + (centerY - courtRect.minY) * 0.55
        path.move(to: CGPoint(x: courtRect.minX, y: topServiceY))
        path.addLine(to: CGPoint(x: courtRect.maxX, y: topServiceY))

        // Service boxes - bottom half
        let bottomServiceY = centerY + (courtRect.maxY - centerY) * 0.45
        path.move(to: CGPoint(x: courtRect.minX, y: bottomServiceY))
        path.addLine(to: CGPoint(x: courtRect.maxX, y: bottomServiceY))

        // Center service lines
        let centerX = rect.midX
        path.move(to: CGPoint(x: centerX, y: topServiceY))
        path.addLine(to: CGPoint(x: centerX, y: centerY))
        path.move(to: CGPoint(x: centerX, y: centerY))
        path.addLine(to: CGPoint(x: centerX, y: bottomServiceY))

        // Glass wall indicators (small corner marks)
        let glassLength: CGFloat = 8
        // Top corners
        path.move(to: CGPoint(x: courtRect.minX, y: courtRect.minY + glassLength))
        path.addLine(to: CGPoint(x: courtRect.minX - 3, y: courtRect.minY + glassLength))
        path.move(to: CGPoint(x: courtRect.maxX, y: courtRect.minY + glassLength))
        path.addLine(to: CGPoint(x: courtRect.maxX + 3, y: courtRect.minY + glassLength))
        // Bottom corners
        path.move(to: CGPoint(x: courtRect.minX, y: courtRect.maxY - glassLength))
        path.addLine(to: CGPoint(x: courtRect.minX - 3, y: courtRect.maxY - glassLength))
        path.move(to: CGPoint(x: courtRect.maxX, y: courtRect.maxY - glassLength))
        path.addLine(to: CGPoint(x: courtRect.maxX + 3, y: courtRect.maxY - glassLength))

        return path
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
