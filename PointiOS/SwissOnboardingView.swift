//
//  SwissOnboardingView.swift
//  PointiOS
//
//  Comprehensive 6-step onboarding flow
//  Swiss Minimalist Design
//

import SwiftUI
import HealthKit

struct SwissOnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedSports") private var selectedSportsData: Data = Data()

    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedSports: Set<String> = []
    @State private var isWatchSearching = false
    @State private var watchFound = false
    @State private var healthAuthorized = false
    @State private var showingPaywall = false
    @ObservedObject private var pro = ProEntitlements.shared
    @ObservedObject private var storeManager = StoreManager.shared

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case sports = 1
        case watch = 2
        case health = 3
        case pro = 4
        case ready = 5

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .sports: return "Sports"
            case .watch: return "Watch"
            case .health: return "Health"
            case .pro: return "Pro"
            case .ready: return "Ready"
            }
        }
    }

    var body: some View {
        ZStack {
            SwissColors.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, 16)

                // Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(OnboardingStep.welcome)
                    sportsStep.tag(OnboardingStep.sports)
                    watchStep.tag(OnboardingStep.watch)
                    healthStep.tag(OnboardingStep.health)
                    proStep.tag(OnboardingStep.pro)
                    readyStep.tag(OnboardingStep.ready)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Rectangle()
                    .fill(step.rawValue <= currentStep.rawValue ? SwissColors.green : SwissColors.gray200)
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep != .welcome {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation {
                        if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = prev
                        }
                    }
                }) {
                    Text("Back")
                }
                .buttonStyle(SwissSecondaryButtonStyle())
            }

            Spacer()

            // Next/Continue button
            Button(action: {
                HapticManager.shared.impact(.medium)
                handleNextStep()
            }) {
                Text(currentStep == .ready ? "Get Started" : "Continue")
            }
            .buttonStyle(SwissGreenButtonStyle())
            .disabled(!canProceed)
            .opacity(canProceed ? 1 : 0.5)
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .sports:
            return !selectedSports.isEmpty
        case .watch, .health, .pro, .ready:
            return true
        }
    }

    private func handleNextStep() {
        withAnimation {
            if currentStep == .ready {
                completeOnboarding()
            } else if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = next
            }
        }
    }

    private func completeOnboarding() {
        // Save selected sports
        if let encoded = try? JSONEncoder().encode(Array(selectedSports)) {
            selectedSportsData = encoded
        }
        hasCompletedOnboarding = true
        HapticManager.shared.notification(.success)
        dismiss()
    }

    // MARK: - Step 1: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            VStack(spacing: 24) {
                if let logo = UIImage(named: "logo-trans") {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .scaleAppear(delay: 0.2)
                } else {
                    Text("Point")
                        .font(.system(size: 48, weight: .bold))
                        .tracking(-2)
                        .foregroundColor(SwissColors.black)
                }

                Text("Track your game.\nElevate your play.")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-1)
                    .multilineTextAlignment(.center)
                    .foregroundColor(SwissColors.black)
                    .slideUpAppear(delay: 0.3)
            }

            // Features
            VStack(spacing: 20) {
                OnboardingFeatureRow(
                    icon: "applewatch",
                    title: "Apple Watch Tracking",
                    description: "Automatic shot detection and scoring"
                )
                .slideUpAppear(delay: 0.4)

                OnboardingFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Performance Insights",
                    description: "Detailed analytics and trends"
                )
                .slideUpAppear(delay: 0.5)

                OnboardingFeatureRow(
                    icon: "square.and.arrow.up",
                    title: "Share Your Wins",
                    description: "Beautiful shareable session cards"
                )
                .slideUpAppear(delay: 0.6)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: Sports Selection
    private var sportsStep: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Text("What do you play?")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(SwissColors.black)

                Text("Select all that apply")
                    .font(SwissTypography.monoLabel(12))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(SwissColors.textSecondary)
            }
            .padding(.top, 48)

            // Sports Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                SportSelectionCard(
                    emoji: "🎾",
                    name: "Tennis",
                    isSelected: selectedSports.contains("Tennis")
                ) {
                    toggleSport("Tennis")
                }
                .staggeredAppear(index: 0, total: 4)

                SportSelectionCard(
                    emoji: "🥒",
                    name: "Pickleball",
                    isSelected: selectedSports.contains("Pickleball")
                ) {
                    toggleSport("Pickleball")
                }
                .staggeredAppear(index: 1, total: 4)

                SportSelectionCard(
                    emoji: "🏓",
                    name: "Padel",
                    isSelected: selectedSports.contains("Padel")
                ) {
                    toggleSport("Padel")
                }
                .staggeredAppear(index: 2, total: 4)

                SportSelectionCard(
                    emoji: "🎯",
                    name: "All Sports",
                    isSelected: selectedSports.count == 3
                ) {
                    if selectedSports.count == 3 {
                        selectedSports.removeAll()
                    } else {
                        selectedSports = ["Tennis", "Pickleball", "Padel"]
                    }
                    HapticManager.shared.impact(.medium)
                }
                .staggeredAppear(index: 3, total: 4)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Selection indicator
            if !selectedSports.isEmpty {
                Text("\(selectedSports.count) sport\(selectedSports.count == 1 ? "" : "s") selected")
                    .font(SwissTypography.monoLabel(11))
                    .foregroundColor(SwissColors.green)
                    .padding(.bottom, 16)
            }
        }
    }

    private func toggleSport(_ sport: String) {
        HapticManager.shared.selection()
        if selectedSports.contains(sport) {
            selectedSports.remove(sport)
        } else {
            selectedSports.insert(sport)
        }
    }

    // MARK: - Step 3: Watch Pairing
    private var watchStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Watch animation
            WatchScanningAnimation(isSearching: $isWatchSearching, isConnected: watchConnectivity.isWatchConnected)
                .frame(height: 200)

            // Status
            VStack(spacing: 12) {
                Text(watchConnectivity.isWatchConnected ? "Watch Connected!" : "Pair Your Apple Watch")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(SwissColors.black)

                Text(watchConnectivity.isWatchConnected ?
                     "Your Apple Watch is ready to track games" :
                     "Open the Point app on your Apple Watch to connect")
                    .font(.system(size: 16))
                    .foregroundColor(SwissColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Wear Tip")
                    .font(SwissTypography.monoLabel(10))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(SwissColors.textSecondary)

                Text("Wear your Apple Watch on your swinging hand for the most accurate shot detection and insights.")
                    .font(.system(size: 14))
                    .foregroundColor(SwissColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SwissColors.gray50)
            )
            .padding(.horizontal, 24)

            // Connection status indicator
            HStack(spacing: 12) {
                Circle()
                    .fill(watchConnectivity.isWatchConnected ? SwissColors.green : SwissColors.gray300)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(watchConnectivity.isWatchConnected ? SwissColors.green.opacity(0.3) : Color.clear, lineWidth: 4)
                            .scaleEffect(isWatchSearching ? 2 : 1)
                            .opacity(isWatchSearching ? 0 : 1)
                            .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: isWatchSearching)
                    )

                Text(watchConnectivity.isWatchConnected ? "Connected" : "Searching...")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(watchConnectivity.isWatchConnected ? SwissColors.green : SwissColors.textSecondary)
            }

            Spacer()

            // Skip option
            if !watchConnectivity.isWatchConnected {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    handleNextStep()
                }) {
                    Text("I'll connect later")
                        .font(SwissTypography.monoLabel(11))
                        .foregroundColor(SwissColors.textSecondary)
                        .underline()
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            isWatchSearching = true
        }
    }

    // MARK: - Step 4: Health Permissions
    private var healthStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "heart.fill")
                .font(.system(size: 64))
                .foregroundColor(SwissColors.red)
                .scaleAppear(delay: 0.1)

            // Header
            VStack(spacing: 12) {
                Text("Health Access")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(SwissColors.black)

                Text("Track calories burned and heart rate during your matches")
                    .font(.system(size: 16))
                    .foregroundColor(SwissColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            // Permissions list
            VStack(spacing: 16) {
                HealthPermissionRow(icon: "flame.fill", title: "Active Calories", color: .orange)
                HealthPermissionRow(icon: "heart.fill", title: "Heart Rate", color: SwissColors.red)
                HealthPermissionRow(icon: "figure.run", title: "Workouts", color: SwissColors.green)
            }
            .padding(.horizontal, 24)
            .slideUpAppear(delay: 0.2)

            Spacer()

            // Authorize button
            if !healthAuthorized {
                Button(action: {
                    requestHealthPermissions()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Continue")
                    }
                }
                .buttonStyle(SwissGreenButtonStyle())
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(SwissColors.green)
                    Text("Health Access Granted")
                        .font(SwissTypography.monoLabel(12))
                        .foregroundColor(SwissColors.green)
                }
            }

            Text("You can manage Health access anytime in Settings.")
                .font(SwissTypography.monoLabel(10))
                .foregroundColor(SwissColors.textSecondary)
                .padding(.bottom, 16)
        }
    }

    private func requestHealthPermissions() {
        HapticManager.shared.impact(.medium)
        // Request HealthKit permissions
        let healthStore = HKHealthStore()
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.workoutType()
        ]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
            DispatchQueue.main.async {
                healthAuthorized = success
                if success {
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }

    // MARK: - Step 5: Pro Upsell
    private var proStep: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Unlock Point Pro")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(SwissColors.black)

                Text("Get the most out of Point")
                    .font(.system(size: 16))
                    .foregroundColor(SwissColors.textSecondary)
            }
            .padding(.top, 32)

            // Free vs Pro comparison
            VStack(spacing: 16) {
                // Free tier info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FREE")
                            .font(SwissTypography.monoLabel(10))
                            .tracking(1)
                            .foregroundColor(SwissColors.textSecondary)
                        Text("3 games • Basic stats")
                            .font(.system(size: 14))
                            .foregroundColor(SwissColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(SwissColors.green)
                }
                .padding(16)
                .background(SwissColors.gray50)
                .overlay(Rectangle().stroke(SwissColors.gray200, lineWidth: 1))

                // Pro tier info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRO")
                            .font(SwissTypography.monoLabel(10))
                            .tracking(1)
                            .foregroundColor(SwissColors.green)
                        Text("Unlimited games • All insights")
                            .font(.system(size: 14))
                            .foregroundColor(SwissColors.black)
                    }
                    Spacer()
                    Text(storeManager.monthlyPrice)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(SwissColors.black)
                    Text("/mo")
                        .font(SwissTypography.monoLabel(11))
                        .foregroundColor(SwissColors.textSecondary)
                }
                .padding(16)
                .background(SwissColors.white)
                .overlay(Rectangle().stroke(SwissColors.green, lineWidth: 2))
            }
            .padding(.horizontal, 24)
            .scaleAppear(delay: 0.2)

            // Features
            VStack(alignment: .leading, spacing: 12) {
                ProFeatureRow(text: "Unlimited game history")
                ProFeatureRow(text: "Full shot analytics & breakdown")
                ProFeatureRow(text: "Performance trends & insights")
                ProFeatureRow(text: "Export & share detailed stats")
            }
            .padding(.horizontal, 32)
            .slideUpAppear(delay: 0.3)

            Spacer()

            // CTA
            if !pro.isPro {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    showingPaywall = true
                }) {
                    Text("Upgrade to Pro")
                }
                .buttonStyle(SwissGreenButtonStyle())
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(SwissColors.green)
                    Text("You have Point Pro")
                        .font(SwissTypography.monoLabel(12))
                        .foregroundColor(SwissColors.green)
                }
            }

            // Skip
            Button(action: {
                HapticManager.shared.impact(.light)
                handleNextStep()
            }) {
                Text(pro.isPro ? "Continue" : "Continue with Free")
                    .font(SwissTypography.monoLabel(11))
                    .foregroundColor(SwissColors.textSecondary)
                    .underline()
            }
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showingPaywall) {
            PointPaywallView()
        }
    }

    // MARK: - Step 6: Ready
    private var readyStep: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success animation
            AnimatedCheckmark(size: 100, color: SwissColors.green)

            // Header
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(SwissColors.black)
                    .slideUpAppear(delay: 0.3)

                Text("Start tracking your games with Point")
                    .font(.system(size: 16))
                    .foregroundColor(SwissColors.textSecondary)
                    .slideUpAppear(delay: 0.4)
            }

            // Summary
            VStack(spacing: 16) {
                if !selectedSports.isEmpty {
                    SummaryRow(icon: "sportscourt", text: selectedSports.joined(separator: ", "))
                }
                if watchConnectivity.isWatchConnected {
                    SummaryRow(icon: "applewatch", text: "Watch connected")
                }
                if healthAuthorized {
                    SummaryRow(icon: "heart.fill", text: "Health access enabled")
                }
            }
            .padding(.horizontal, 24)
            .slideUpAppear(delay: 0.5)

            Spacer()

            // Tip
            VStack(spacing: 8) {
                Text("Quick Tip")
                    .font(SwissTypography.monoLabel(10))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(SwissColors.textSecondary)

                Text("Open Point on your Apple Watch before starting a game for automatic tracking")
                    .font(.system(size: 14))
                    .foregroundColor(SwissColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(SwissColors.greenLight)
            .overlay(
                Rectangle()
                    .stroke(SwissColors.green, lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .slideUpAppear(delay: 0.6)
        }
    }
}

// MARK: - Supporting Components

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(SwissColors.green)
                .frame(width: 48, height: 48)
                .background(SwissColors.greenLight)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SwissColors.black)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(SwissColors.textSecondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct SportSelectionCard: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 48))

                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? SwissColors.white : SwissColors.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(isSelected ? SwissColors.green : SwissColors.white)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? SwissColors.green : SwissColors.gray200, lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1)
        .animation(SwissAnimation.snappy, value: isSelected)
        .accessibilityLabel("\(name), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct WatchScanningAnimation: View {
    @Binding var isSearching: Bool
    let isConnected: Bool

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        ZStack {
            // Pulse rings
            ForEach(0..<3) { i in
                Circle()
                    .stroke(isConnected ? SwissColors.green.opacity(0.3) : SwissColors.gray300.opacity(0.3), lineWidth: 2)
                    .scaleEffect(pulseScale + CGFloat(i) * 0.3)
                    .opacity(isSearching && !isConnected ? Double(3 - i) / 3 : 0)
            }

            // Watch icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isConnected ? SwissColors.green : SwissColors.gray200)
                    .frame(width: 80, height: 100)

                VStack(spacing: 4) {
                    Image(systemName: isConnected ? "checkmark" : "applewatch")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(isConnected ? SwissColors.white : SwissColors.gray500)

                    if isConnected {
                        Text("PAIRED")
                            .font(SwissTypography.monoLabel(8))
                            .foregroundColor(SwissColors.white)
                    }
                }
            }
            .rotationEffect(.degrees(isSearching && !isConnected ? rotation : 0))
        }
        .onAppear {
            if isSearching && !isConnected {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 5
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.5
                }
            }
        }
        .onChange(of: isConnected) { _, connected in
            if connected {
                HapticManager.shared.notification(.success)
            }
        }
    }
}

struct HealthPermissionRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(SwissColors.black)

            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 20))
                .foregroundColor(SwissColors.gray300)
        }
    }
}

struct ProFeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(SwissColors.green)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(SwissColors.black)

            Spacer()
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(SwissColors.green)
                .frame(width: 32)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(SwissColors.black)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(SwissColors.green)
        }
        .padding(16)
        .background(SwissColors.gray50)
        .overlay(
            Rectangle()
                .stroke(SwissColors.gray200, lineWidth: 1)
        )
    }
}

#Preview {
    SwissOnboardingView()
        .environmentObject(WatchConnectivityManager.shared)
}
