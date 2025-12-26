//
//  UpgradeView.swift
//  PointiOS
//
//  Swiss-styled Upgrade/Paywall View with StoreKit 2 integration
//

import SwiftUI
import StoreKit

// MARK: - Point Paywall View (for sheets)
struct PointPaywallView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        UpgradeView()
    }
}

// MARK: - Upgrade View
struct UpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.isDarkMode) var isDarkMode
    @ObservedObject private var pro = ProEntitlements.shared
    @ObservedObject private var storeManager = StoreManager.shared

    @State private var selectedPlan: PlanType = .yearly
    @State private var showingError = false
    @State private var showingSuccess = false

    enum PlanType {
        case monthly, yearly
    }

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection(colors: colors)

                    // Pricing Cards
                    pricingSection(colors: colors)

                    // Features List
                    featuresSection(colors: colors)

                    // Purchase Button
                    purchaseButton(colors: colors)

                    // Restore & Terms
                    footerSection(colors: colors)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(colors.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colors.textSecondary)
                    }
                }
            }
        }
        .alert("Purchase Failed", isPresented: $showingError) {
            Button("OK") { storeManager.clearError() }
        } message: {
            Text(storeManager.errorMessage ?? "Something went wrong")
        }
        .alert("Welcome to Pro!", isPresented: $showingSuccess) {
            Button("Let's Go") { dismiss() }
        } message: {
            Text("You now have access to all Point Pro features.")
        }
        .onAppear {
            Task {
                await storeManager.loadProducts()
            }
        }
    }

    // MARK: - Header
    private func headerSection(colors: SwissAdaptiveColors) -> some View {
        VStack(spacing: 12) {
            // Pro Badge
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                Text("POINT PRO")
                    .font(SwissTypography.monoLabel(11))
                    .tracking(1.5)
            }
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(SwissColors.green)

            Text("Unlock Your\nFull Potential")
                .font(.system(size: 32, weight: .bold))
                .tracking(-1)
                .multilineTextAlignment(.center)
                .foregroundColor(colors.textPrimary)

            Text("Unlimited games and full analytics")
                .font(SwissTypography.monoLabel(12))
                .foregroundColor(colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Pricing Cards
    private func pricingSection(colors: SwissAdaptiveColors) -> some View {
        VStack(spacing: 12) {
            // Yearly Plan
            SwissPricingCard(
                title: "YEARLY",
                price: storeManager.annualPrice,
                period: "/year",
                subtext: "\(storeManager.annualPricePerMonth)/mo",
                badge: storeManager.savingsPercent > 0 ? "SAVE \(storeManager.savingsPercent)%" : "BEST VALUE",
                isSelected: selectedPlan == .yearly,
                colors: colors
            ) {
                HapticManager.shared.impact(.light)
                selectedPlan = .yearly
            }

            // Monthly Plan
            SwissPricingCard(
                title: "MONTHLY",
                price: storeManager.monthlyPrice,
                period: "/month",
                subtext: nil,
                badge: nil,
                isSelected: selectedPlan == .monthly,
                colors: colors
            ) {
                HapticManager.shared.impact(.light)
                selectedPlan = .monthly
            }
        }
    }

    // MARK: - Features
    private func featuresSection(colors: SwissAdaptiveColors) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WHAT'S INCLUDED")
                .font(SwissTypography.monoLabel(10))
                .tracking(1.5)
                .foregroundColor(colors.textTertiary)

            ForEach(ProFeature.allCases, id: \.self) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16))
                        .foregroundColor(SwissColors.green)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colors.textPrimary)

                        Text(feature.description)
                            .font(SwissTypography.monoLabel(10))
                            .foregroundColor(colors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(SwissColors.green)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(colors.surface)
        .overlay(
            Rectangle()
                .stroke(colors.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Purchase Button
    private func purchaseButton(colors: SwissAdaptiveColors) -> some View {
        Button(action: purchase) {
            HStack(spacing: 8) {
                if storeManager.isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("CONTINUE")
                        .font(SwissTypography.monoLabel(13))
                        .tracking(1.5)
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(SwissColors.green)
        }
        .disabled(storeManager.isLoading)
        .opacity(storeManager.isLoading ? 0.7 : 1)
    }

    // MARK: - Footer
    private func footerSection(colors: SwissAdaptiveColors) -> some View {
        VStack(spacing: 16) {
            Button(action: restore) {
                HStack(spacing: 8) {
                    if storeManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Restore Purchases")
                        .font(SwissTypography.monoLabel(11))
                        .foregroundColor(colors.textSecondary)
                        .underline()
                }
            }
            .disabled(storeManager.isLoading)

            if pro.isPro {
                Button(action: {
                    Task {
                        await storeManager.showManageSubscriptions()
                    }
                }) {
                    Text("Manage Subscription")
                        .font(SwissTypography.monoLabel(11))
                        .foregroundColor(colors.textSecondary)
                        .underline()
                }
            }

            Text("Cancel anytime. Subscription auto-renews until cancelled.")
                .font(SwissTypography.monoLabel(9))
                .foregroundColor(colors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms", destination: URL(string: "https://point.app/terms")!)
                    .font(SwissTypography.monoLabel(9))
                    .foregroundColor(colors.textTertiary)

                Text("•")
                    .foregroundColor(colors.textTertiary)

                Link("Privacy", destination: URL(string: "https://point.app/privacy")!)
                    .font(SwissTypography.monoLabel(9))
                    .foregroundColor(colors.textTertiary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions
    private func purchase() {
        Task {
            let success: Bool
            if selectedPlan == .yearly {
                success = await storeManager.purchaseAnnual()
            } else {
                success = await storeManager.purchaseMonthly()
            }

            if success {
                HapticManager.shared.notification(.success)
                showingSuccess = true
            } else if storeManager.errorMessage != nil {
                HapticManager.shared.notification(.error)
                showingError = true
            }
        }
    }

    private func restore() {
        Task {
            let success = await storeManager.restorePurchases()
            if success {
                HapticManager.shared.notification(.success)
                showingSuccess = true
            } else if storeManager.errorMessage != nil {
                HapticManager.shared.notification(.error)
                showingError = true
            }
        }
    }
}

// MARK: - Swiss Pricing Card
struct SwissPricingCard: View {
    let title: String
    let price: String
    let period: String
    let subtext: String?
    let badge: String?
    let isSelected: Bool
    let colors: SwissAdaptiveColors
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(SwissTypography.monoLabel(11))
                            .tracking(1)
                            .foregroundColor(colors.textSecondary)

                        if let badge = badge {
                            Text(badge)
                                .font(SwissTypography.monoLabel(8))
                                .tracking(0.5)
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(SwissColors.green)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(price)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1)
                            .foregroundColor(colors.textPrimary)

                        Text(period)
                            .font(SwissTypography.monoLabel(11))
                            .foregroundColor(colors.textTertiary)
                    }

                    if let subtext = subtext {
                        Text(subtext)
                            .font(SwissTypography.monoLabel(10))
                            .foregroundColor(colors.textTertiary)
                    }
                }

                Spacer()

                // Selection indicator
                Circle()
                    .fill(isSelected ? SwissColors.green : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? SwissColors.green : colors.borderSubtle, lineWidth: 2)
                    )
                    .overlay(
                        isSelected ?
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black) : nil
                    )
            }
            .padding(20)
            .background(colors.surface)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? SwissColors.green : colors.borderSubtle, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Locked Feature Card (for use elsewhere in app)
struct LockedFeatureCard: View {
    @Environment(\.isDarkMode) var isDarkMode
    let title: String
    let description: String
    let action: () -> Void

    init(title: String, description: String, action: @escaping () -> Void) {
        self.title = title
        self.description = description
        self.action = action
    }

    init(feature: ProFeature, action: @escaping () -> Void) {
        self.title = feature.rawValue
        self.description = feature.description
        self.action = action
    }

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(SwissColors.green)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Text("PRO")
                    .font(SwissTypography.monoLabel(9))
                    .tracking(1)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SwissColors.green)
            }

            Text(description)
                .font(SwissTypography.monoLabel(11))
                .foregroundColor(colors.textSecondary)

            Button(action: action) {
                Text("UNLOCK PRO")
                    .font(SwissTypography.monoLabel(10))
                    .tracking(1)
                    .foregroundColor(colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        Rectangle()
                            .stroke(colors.border, lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(colors.surface)
        .overlay(
            Rectangle()
                .stroke(colors.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Subscription Status Card (for Profile/Settings)
struct SubscriptionStatusCard: View {
    @Environment(\.isDarkMode) var isDarkMode
    @ObservedObject private var storeManager = StoreManager.shared
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingUpgrade = false

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: pro.isPro ? "star.fill" : "star")
                            .foregroundColor(SwissColors.green)
                        Text(pro.isPro ? "POINT PRO" : "FREE PLAN")
                            .font(SwissTypography.monoLabel(12))
                            .tracking(1.5)
                            .foregroundColor(colors.textPrimary)
                    }

                    Text(pro.isPro ? "You have full access" : "Upgrade for unlimited access")
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                if pro.isPro {
                    // Pro badge
                    Text("ACTIVE")
                        .font(SwissTypography.monoLabel(9))
                        .tracking(1)
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SwissColors.green)
                }
            }

            // Action button
            if pro.isPro {
                Button(action: {
                    Task {
                        await storeManager.showManageSubscriptions()
                    }
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("MANAGE SUBSCRIPTION")
                    }
                    .font(SwissTypography.monoLabel(11))
                    .tracking(1)
                    .foregroundColor(colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        Rectangle()
                            .stroke(colors.border, lineWidth: 1)
                    )
                }
            } else {
                Button(action: { showingUpgrade = true }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("UPGRADE TO PRO")
                    }
                    .font(SwissTypography.monoLabel(11))
                    .tracking(1)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SwissColors.green)
                }
            }
        }
        .padding(20)
        .background(colors.surface)
        .overlay(
            Rectangle()
                .stroke(colors.borderSubtle, lineWidth: 1)
        )
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
        }
    }
}

// MARK: - Preview
#Preview("Upgrade View") {
    UpgradeView()
        .environment(\.isDarkMode, true)
}

#Preview("Subscription Status - Pro") {
    SubscriptionStatusCard()
        .padding()
        .environment(\.isDarkMode, true)
}

#Preview("Locked Feature Card") {
    LockedFeatureCard(
        title: "Advanced Analytics",
        description: "Get detailed insights into your game performance"
    ) {
        print("Upgrade tapped")
    }
    .padding()
    .environment(\.isDarkMode, true)
}
