//
//  SwissProfileView.swift
//  PointiOS
//
//  Swiss Minimalist Profile View - Redesigned with Playstyles & Achievements
//

import SwiftUI

// MARK: - Play Style Definition
enum PlayStyle: String, CaseIterable {
    // Tennis
    case baseliner = "Baseliner"
    case aggressiveBaseliner = "Aggressive Baseliner"
    case serveAndVolley = "Serve & Volley"
    case allCourt = "All-Court"
    case counterpuncher = "Counterpuncher"

    // Padel
    case defensive = "Defensive"
    case aggressiveFinisher = "Aggressive Finisher"
    case controlPlacement = "Control / Placement"

    // Pickleball
    case dinker = "Dinker"
    case banger = "Banger"
    case hybrid = "Hybrid"
    case netPressure = "Net Pressure"

    var icon: String {
        switch self {
        // Tennis
        case .baseliner: return "arrow.left.and.right"
        case .aggressiveBaseliner: return "flame"
        case .serveAndVolley: return "arrow.up.forward"
        case .allCourt: return "square.grid.2x2"
        case .counterpuncher: return "arrow.uturn.backward"
        // Padel
        case .defensive: return "shield"
        case .aggressiveFinisher: return "bolt.fill"
        case .controlPlacement: return "target"
        // Pickleball
        case .dinker: return "drop"
        case .banger: return "bolt.fill"
        case .hybrid: return "arrow.triangle.branch"
        case .netPressure: return "arrow.up.to.line"
        }
    }

    var description: String {
        switch self {
        // Tennis
        case .baseliner: return "Controls rallies from the baseline"
        case .aggressiveBaseliner: return "Attacks with power from the back"
        case .serveAndVolley: return "Attacks the net after serving"
        case .allCourt: return "Adapts to all situations"
        case .counterpuncher: return "Turns defense into offense"
        // Padel
        case .defensive: return "Patient wall-based defense"
        case .aggressiveFinisher: return "Closes points at the net"
        case .controlPlacement: return "Precise shot placement"
        // Pickleball
        case .dinker: return "Patient soft game specialist"
        case .banger: return "Power-focused aggressive play"
        case .hybrid: return "Mix of power and finesse"
        case .netPressure: return "Dominates at the kitchen line"
        }
    }
}

struct SwissProfileView: View {
    @Environment(\.adaptiveColors) var colors
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var achievementManager = AchievementManager.shared
    @State private var showingAchievements = false
    @State private var showingSettings = false
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingProSheet = false

    // Rating edit states
    @State private var showingRatingEdit = false
    @State private var selectedSettingsItem: String? = nil

    // Playstyle selection states
    @State private var showingPlayStylePicker = false
    @State private var editingPlayStyleSport: String = ""
    @AppStorage("tennisPlayStyle") private var selectedTennisPlayStyle: String = "Baseliner"
    @AppStorage("pickleballPlayStyle") private var selectedPickleballPlayStyle: String = "Dinker"
    @AppStorage("padelPlayStyle") private var selectedPadelPlayStyle: String = "Defensive"

    // Animation states
    @State private var headerVisible = false
    @State private var ratingsVisible = false
    @State private var stylesVisible = false
    @State private var achievementsVisible = false
    @State private var settingsVisible = false

    // XP value from XPManager
    private var xpValue: Int {
        XPManager.shared.totalXP
    }

    // Member since date (just year)
    private var memberSinceYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        // Use app start date if available, otherwise default to 2023
        if let startDate = UserDefaults.standard.object(forKey: "appFirstLaunchDate") as? Date {
            return formatter.string(from: startDate)
        }
        return "2023"
    }


    // Current win streak computed from games
    private var currentWinStreak: Int {
        var streak = 0
        for game in watchConnectivity.receivedGames.sorted(by: { $0.date > $1.date }) {
            if game.winner == "You" {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // Top achievements (unlocked)
    private var topAchievements: [(AchievementDefinition, AchievementProgress)] {
        achievementManager.getTopAchievements(count: 6)
    }

    // Unlocked count
    private var unlockedCount: Int {
        achievementManager.userProgress.values.filter { $0.highestTierAchieved != nil }.count
    }

    // Total achievements
    private var totalAchievements: Int {
        AchievementDefinitions.shared.definitions.count
    }

    // Games stats
    private var totalGames: Int {
        watchConnectivity.receivedGames.count
    }

    private var totalWins: Int {
        watchConnectivity.receivedGames.filter { $0.winner == "You" }.count
    }

    // Sports played
    private var sportsPlayed: Set<String> {
        Set(watchConnectivity.receivedGames.map { $0.sportType })
    }

    // Games per sport
    private var tennisGames: Int {
        watchConnectivity.receivedGames.filter { $0.sportType == "Tennis" }.count
    }

    private var pickleballGames: Int {
        watchConnectivity.receivedGames.filter { $0.sportType == "Pickleball" }.count
    }

    private var padelGames: Int {
        watchConnectivity.receivedGames.filter { $0.sportType == "Padel" }.count
    }

    // Play styles per sport (user selected, stored in AppStorage)
    private var tennisPlayStyle: PlayStyle {
        PlayStyle(rawValue: selectedTennisPlayStyle) ?? .baseliner
    }

    private var pickleballPlayStyle: PlayStyle {
        PlayStyle(rawValue: selectedPickleballPlayStyle) ?? .dinker
    }

    private var padelPlayStyle: PlayStyle {
        PlayStyle(rawValue: selectedPadelPlayStyle) ?? .defensive
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 20)

                // Ratings Section
                ratingsSection
                    .opacity(ratingsVisible ? 1 : 0)
                    .offset(y: ratingsVisible ? 0 : 20)

                // Play Styles Section
                playStylesSection
                    .opacity(stylesVisible ? 1 : 0)
                    .offset(y: stylesVisible ? 0 : 20)

                // Achievements Section
                achievementsSection
                    .opacity(achievementsVisible ? 1 : 0)
                    .offset(y: achievementsVisible ? 0 : 20)

                // Settings Menu
                settingsSection
                    .opacity(settingsVisible ? 1 : 0)
                    .offset(y: settingsVisible ? 0 : 20)

                Color.clear.frame(height: 100)
            }
        }
        .background(colors.background)
        .onAppear {
            animateIn()
        }
        .sheet(isPresented: $showingAchievements) {
            SwissAchievementsModal()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(appData)
                .environmentObject(watchConnectivity)
        }
        .sheet(isPresented: $showingProSheet) {
            UpgradeView()
        }
        .sheet(isPresented: $showingRatingEdit) {
            SwissRatingEditSheet(
                onSave: {
                    showingRatingEdit = false
                }
            )
            .environmentObject(appData)
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPlayStylePicker) {
            SwissPlayStylePickerSheet(
                sport: editingPlayStyleSport,
                selectedStyle: Binding(
                    get: {
                        switch editingPlayStyleSport {
                        case "Tennis": return selectedTennisPlayStyle
                        case "Pickleball": return selectedPickleballPlayStyle
                        case "Padel": return selectedPadelPlayStyle
                        default: return "Balanced"
                        }
                    },
                    set: { newValue in
                        switch editingPlayStyleSport {
                        case "Tennis": selectedTennisPlayStyle = newValue
                        case "Pickleball": selectedPickleballPlayStyle = newValue
                        case "Padel": selectedPadelPlayStyle = newValue
                        default: break
                        }
                    }
                ),
                onDismiss: { showingPlayStylePicker = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Animate In
    private func animateIn() {
        withAnimation(SwissAnimation.gentle.delay(0.1)) {
            headerVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.15)) {
            ratingsVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.25)) {
            stylesVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.35)) {
            achievementsVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.45)) {
            settingsVisible = true
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Name
                Text(appData.displayName)
                    .font(.system(size: 36, weight: .black))
                    .tracking(-1)
                    .foregroundColor(colors.textPrimary)

                // Member since and XP
                HStack(spacing: 12) {
                    Text("Member since \(memberSinceYear)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colors.textSecondary)

                    Spacer()

                    // XP Badge
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showingAchievements = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("\(xpValue.formatted()) XP")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .textCase(.uppercase)
                        }
                        .foregroundColor(SwissColors.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(SwissColors.green)
                    }
                    .pressEffect()
                }
            }
            .padding(24)

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
        }
    }

    // MARK: - Ratings Section
    private var ratingsSection: some View {
        VStack(spacing: 0) {
            // Section Header with Edit button
            HStack {
                Text("Ratings")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Button(action: {
                    HapticManager.shared.impact(.light)
                    showingRatingEdit = true
                }) {
                    Text("Edit")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundColor(SwissColors.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .stroke(SwissColors.green, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Ratings Grid - wider cells
            HStack(spacing: 0) {
                // Tennis UTR
                SwissRatingCell(
                    sport: "Tennis",
                    ratingType: "UTR",
                    value: appData.utrScore,
                    gamesPlayed: tennisGames
                )

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(width: 1)

                // Pickle DUPR
                SwissRatingCell(
                    sport: "Pickleball",
                    ratingType: "DUPR",
                    value: appData.duprScore,
                    gamesPlayed: pickleballGames
                )

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(width: 1)

                // Padel PTC
                SwissRatingCell(
                    sport: "Padel",
                    ratingType: "PTC",
                    value: appData.playtomicScore,
                    gamesPlayed: padelGames
                )
            }
            .overlay(
                Rectangle()
                    .stroke(SwissColors.gray, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
                .padding(.top, 24)
        }
    }

    // MARK: - Play Styles Section
    private var playStylesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Play Styles")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Text("Tap to change")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colors.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // Play Style Cards - tappable
            VStack(spacing: 12) {
                SwissPlayStyleCard(
                    sport: "Tennis",
                    style: tennisPlayStyle,
                    gamesAnalyzed: tennisGames,
                    onTap: {
                        editingPlayStyleSport = "Tennis"
                        showingPlayStylePicker = true
                    }
                )
                .staggeredAppear(index: 0, total: 3)

                SwissPlayStyleCard(
                    sport: "Pickleball",
                    style: pickleballPlayStyle,
                    gamesAnalyzed: pickleballGames,
                    onTap: {
                        editingPlayStyleSport = "Pickleball"
                        showingPlayStylePicker = true
                    }
                )
                .staggeredAppear(index: 1, total: 3)

                SwissPlayStyleCard(
                    sport: "Padel",
                    style: padelPlayStyle,
                    gamesAnalyzed: padelGames,
                    onTap: {
                        editingPlayStyleSport = "Padel"
                        showingPlayStylePicker = true
                    }
                )
                .staggeredAppear(index: 2, total: 3)
            }
            .padding(.horizontal, 24)

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
                .padding(.top, 16)
        }
    }

    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Achievements")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(colors.textPrimary)

                Text("\(unlockedCount)/\(totalAchievements)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(colors.textSecondary)
                    .padding(.leading, 8)

                Spacer()

                Button(action: {
                    HapticManager.shared.impact(.light)
                    showingAchievements = true
                }) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(colors.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // Achievement Cards
            if topAchievements.isEmpty && watchConnectivity.receivedGames.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Text("🏆")
                        .font(.system(size: 32))
                        .grayscale(1)
                    Text("No achievements yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors.textSecondary)
                    Text("Play games to unlock achievements")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(SwissColors.textMuted)
                        .padding(.horizontal, 24)
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    // Active achievement (win streak) if applicable
                    if currentWinStreak > 0 {
                        SwissAchievementCard(
                            emoji: "🔥",
                            title: "Win Streak",
                            value: "\(currentWinStreak)",
                            subtitle: "Consecutive Wins",
                            isActive: true
                        )
                        .staggeredAppear(index: 0, total: 6)
                    }

                    // Show unlocked achievements
                    ForEach(Array(topAchievements.prefix(currentWinStreak > 0 ? 5 : 6).enumerated()), id: \.element.0.type) { index, item in
                        let (definition, progress) = item
                        SwissAchievementCard(
                            emoji: definition.icon,
                            title: definition.name,
                            value: "\(progress.currentValue)",
                            subtitle: progress.highestTierAchieved?.name ?? "In Progress",
                            isActive: false,
                            tier: progress.highestTierAchieved
                        )
                        .staggeredAppear(index: index + (currentWinStreak > 0 ? 1 : 0), total: 6)
                    }
                }
                .padding(.horizontal, 24)
            }

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
                .padding(.top, 16)
        }
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 16) {
            // Settings Button
            Button(action: {
                HapticManager.shared.impact(.light)
                showingSettings = true
            }) {
                HStack {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(1.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colors.textTertiary)
                }
                .foregroundColor(colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .overlay(
                    Rectangle()
                        .stroke(colors.borderSubtle, lineWidth: 1)
                )
            }
            .pressEffect()

            // Logout Button
            Button(action: {
                HapticManager.shared.notification(.warning)
                authManager.signOut()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Log Out")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
                .foregroundColor(SwissColors.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    Rectangle()
                        .stroke(SwissColors.red.opacity(0.3), lineWidth: 1)
                )
            }
            .pressEffect()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}

// MARK: - Supporting Views

struct SwissRatingCell: View {
    @Environment(\.adaptiveColors) var colors
    let sport: String
    let ratingType: String
    let value: String
    let gamesPlayed: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(sport)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)

            Text(value)
                .font(.system(size: 36, weight: .black))
                .tracking(-2)
                .foregroundColor(colors.textPrimary)

            Text(ratingType)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct SwissPlayStyleCard: View {
    @Environment(\.adaptiveColors) var colors
    let sport: String
    let style: PlayStyle
    let gamesAnalyzed: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            onTap?()
        }) {
            HStack(spacing: 16) {
                // Sport icon
                ZStack {
                    Rectangle()
                        .fill(colors.isDarkMode ? SwissColors.green : SwissColors.gray100)
                        .frame(width: 48, height: 48)

                    Image(systemName: style.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(colors.isDarkMode ? SwissColors.white : colors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(sport)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(colors.textSecondary)

                    Text(style.rawValue)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(colors.textPrimary)

                    Text(style.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(colors.textTertiary)
                }

                Spacer()

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colors.textTertiary)
            }
            .padding(16)
            .overlay(
                Rectangle()
                    .stroke(SwissColors.gray, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SwissAchievementCard: View {
    @Environment(\.adaptiveColors) var colors
    let emoji: String
    let title: String
    let value: String
    let subtitle: String
    var isActive: Bool = false
    var tier: AchievementTier? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(emoji)
                    .font(.system(size: 26))
                    .grayscale(isActive ? 0 : (tier != nil ? 0 : 1))

                Spacer()

                if isActive {
                    Text("Active")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(SwissColors.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SwissColors.green)
                } else if let tier = tier {
                    Text(tier.name)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(tier == .gold || tier == .platinum ? SwissColors.black : SwissColors.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tier.color)
                }
            }

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textPrimary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 28, weight: .black))
                .tracking(-1)
                .foregroundColor(isActive ? SwissColors.green : SwissColors.black)

            Text(subtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(colors.textSecondary)
        }
        .padding(18)
        .overlay(
            Rectangle()
                .stroke(isActive ? SwissColors.green : (tier != nil ? tier!.color : SwissColors.gray), lineWidth: isActive ? 2 : (tier != nil ? 2 : 1))
        )
        .background(
            isActive ? SwissColors.greenLight : SwissColors.white
        )
    }
}

struct SwissSettingsRow<Content: View>: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    var icon: String? = nil
    var showDivider: Bool = true
    let trailing: Content

    init(title: String, icon: String? = nil, showDivider: Bool = true, @ViewBuilder trailing: () -> Content) {
        self.title = title
        self.icon = icon
        self.showDivider = showDivider
        self.trailing = trailing()
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(SwissColors.textPrimary)
                            .frame(width: 24)
                    }

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SwissColors.textPrimary)

                    Spacer()

                    trailing
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                if showDivider {
                    Rectangle()
                        .fill(colors.borderSubtle)
                        .frame(height: 1)
                        .padding(.leading, icon != nil ? 52 : 16)
                }
            }
        }
        .pressEffect(scale: 0.99)
    }
}

// MARK: - Rating Edit Sheet
struct SwissRatingEditSheet: View {
    @Environment(\.adaptiveColors) var colors
    @EnvironmentObject var appData: AppData
    let onSave: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var utrValue: String = ""
    @State private var duprValue: String = ""
    @State private var ptcValue: String = ""
    @FocusState private var focusedField: RatingField?

    enum RatingField {
        case utr, dupr, ptc
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                Text("Edit Ratings")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(1)

                Spacer()

                Button(action: {
                    HapticManager.shared.impact(.medium)
                    appData.utrScore = utrValue
                    appData.duprScore = duprValue
                    appData.playtomicScore = ptcValue
                    onSave()
                }) {
                    Text("Save")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colors.textPrimary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Ratings List
            VStack(spacing: 20) {
                // Tennis UTR
                ratingRow(
                    sport: "Tennis",
                    ratingType: "UTR",
                    hint: "1.0 - 16.0",
                    value: $utrValue,
                    field: .utr
                )

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                // Pickleball DUPR
                ratingRow(
                    sport: "Pickleball",
                    ratingType: "DUPR",
                    hint: "2.0 - 8.0",
                    value: $duprValue,
                    field: .dupr
                )

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                // Padel PTC
                ratingRow(
                    sport: "Padel",
                    ratingType: "PTC",
                    hint: "1.0 - 10.0",
                    value: $ptcValue,
                    field: .ptc
                )
            }

            Spacer()
        }
        .background(colors.background)
        .onAppear {
            utrValue = appData.utrScore
            duprValue = appData.duprScore
            ptcValue = appData.playtomicScore
        }
    }

    private func ratingRow(sport: String, ratingType: String, hint: String, value: Binding<String>, field: RatingField) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sport)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colors.textPrimary)

                Text("\(ratingType) (\(hint))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            TextField("0.0", text: value)
                .font(.system(size: 28, weight: .black))
                .tracking(-1)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .foregroundColor(colors.textPrimary)
                .focused($focusedField, equals: field)
                .frame(width: 100)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Achievements Modal
struct SwissAchievementsModal: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.adaptiveColors) var colors
    @StateObject private var achievementManager = AchievementManager.shared
    @State private var selectedCategory: AchievementCategory? = nil

    // Animation states
    @State private var headerVisible = false
    @State private var contentVisible = false

    // Unlocked achievements
    private var unlockedAchievements: [(AchievementDefinition, AchievementProgress)] {
        var results: [(AchievementDefinition, AchievementProgress)] = []
        for (type, progress) in achievementManager.userProgress {
            if progress.highestTierAchieved != nil,
               let definition = AchievementDefinitions.shared.definitions[type] {
                if let category = selectedCategory {
                    if definition.category == category {
                        results.append((definition, progress))
                    }
                } else {
                    results.append((definition, progress))
                }
            }
        }
        return results.sorted { $0.1.highestTierAchieved?.rawValue ?? 0 > $1.1.highestTierAchieved?.rawValue ?? 0 }
    }

    // In-progress achievements (have progress but not unlocked)
    private var inProgressAchievements: [(AchievementDefinition, AchievementProgress)] {
        var results: [(AchievementDefinition, AchievementProgress)] = []
        for (type, progress) in achievementManager.userProgress {
            if progress.highestTierAchieved == nil && progress.currentValue > 0,
               let definition = AchievementDefinitions.shared.definitions[type] {
                if let category = selectedCategory {
                    if definition.category == category {
                        results.append((definition, progress))
                    }
                } else {
                    results.append((definition, progress))
                }
            }
        }
        return results.sorted { $0.1.currentValue > $1.1.currentValue }
    }

    // Locked achievements (not yet achieved)
    private var lockedAchievements: [AchievementDefinition] {
        AchievementDefinitions.shared.definitions.values
            .filter { definition in
                let progress = achievementManager.userProgress[definition.type]
                let isLocked = progress?.highestTierAchieved == nil && (progress?.currentValue ?? 0) == 0
                if let category = selectedCategory {
                    return isLocked && definition.category == category
                }
                return isLocked
            }
            .sorted { $0.name < $1.name }
    }

    // Categories for filter
    private var categories: [AchievementCategory] {
        AchievementCategory.allCases
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Achievements")
                            .font(.system(size: 26, weight: .black))
                            .tracking(-0.5)
                            .foregroundColor(colors.textPrimary)

                        HStack(spacing: 8) {
                            Text("\(unlockedAchievements.count) unlocked")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(SwissColors.green)

                            Text("•")
                                .foregroundColor(SwissColors.textMuted)

                            Text("\(achievementManager.totalPoints) pts")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colors.textSecondary)
                        }
                    }

                    Spacer()

                    Button(action: {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Rectangle()
                                    .stroke(SwissColors.gray, lineWidth: 1)
                            )
                    }
                    .pressEffect()
                }
                .padding(24)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : -10)

                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryPill(title: "All", isSelected: selectedCategory == nil) {
                            HapticManager.shared.selection()
                            selectedCategory = nil
                        }

                        ForEach(categories, id: \.self) { category in
                            CategoryPill(title: category.rawValue, isSelected: selectedCategory == category) {
                                HapticManager.shared.selection()
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)

                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Unlocked Achievements
                    if !unlockedAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Circle()
                                    .fill(SwissColors.green)
                                    .frame(width: 8, height: 8)
                                Text("Unlocked")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                    .foregroundColor(SwissColors.green)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(Array(unlockedAchievements.enumerated()), id: \.element.0.type) { index, item in
                                    let (definition, progress) = item
                                    SwissAchievementTile(
                                        definition: definition,
                                        progress: progress,
                                        isUnlocked: true
                                    )
                                    .staggeredAppear(index: index, total: unlockedAchievements.count)
                                }
                            }
                        }
                    }

                    // In Progress Achievements
                    if !inProgressAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Circle()
                                    .fill(SwissColors.yellow)
                                    .frame(width: 8, height: 8)
                                Text("In Progress")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                    .foregroundColor(SwissColors.yellow)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(Array(inProgressAchievements.enumerated()), id: \.element.0.type) { index, item in
                                    let (definition, progress) = item
                                    SwissAchievementTile(
                                        definition: definition,
                                        progress: progress,
                                        isUnlocked: false
                                    )
                                }
                            }
                        }
                    }

                    // Locked Achievements
                    if !lockedAchievements.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Circle()
                                    .fill(SwissColors.textMuted)
                                    .frame(width: 8, height: 8)
                                Text("Locked (\(lockedAchievements.count))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                    .foregroundColor(colors.textTertiary)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(lockedAchievements, id: \.type) { definition in
                                    SwissLockedTile(definition: definition)
                                }
                            }
                        }
                    }

                    // Empty state
                    if unlockedAchievements.isEmpty && inProgressAchievements.isEmpty && lockedAchievements.isEmpty {
                        VStack(spacing: 16) {
                            Text("🏆")
                                .font(.system(size: 48))
                                .grayscale(1)

                            Text("No achievements data")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(colors.textPrimary)

                            Text("Play games to start unlocking achievements")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding(24)
                .opacity(contentVisible ? 1 : 0)
            }
        }
        .background(SwissColors.white)
        .onAppear {
            withAnimation(SwissAnimation.gentle.delay(0.1)) {
                headerVisible = true
            }
            withAnimation(SwissAnimation.gentle.delay(0.2)) {
                contentVisible = true
            }
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? SwissColors.white : SwissColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? SwissColors.black : SwissColors.white)
                .overlay(
                    Rectangle()
                        .stroke(SwissColors.black, lineWidth: 1)
                )
        }
        .pressEffect(scale: 0.97)
    }
}

// MARK: - Achievement Tile with Progress
struct SwissAchievementTile: View {
    @Environment(\.adaptiveColors) var colors
    let definition: AchievementDefinition
    let progress: AchievementProgress
    let isUnlocked: Bool

    private var nextTierRequirement: Int? {
        guard let currentTier = progress.highestTierAchieved else {
            // Find first tier requirement
            return definition.tiers.sorted(by: { $0.key.rawValue < $1.key.rawValue }).first?.value.value
        }

        // Find next tier
        let sortedTiers = definition.tiers.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        for (tier, requirement) in sortedTiers {
            if tier.rawValue > currentTier.rawValue {
                return requirement.value
            }
        }
        return nil
    }

    private var nextTierName: String? {
        guard let currentTier = progress.highestTierAchieved else {
            return definition.tiers.sorted(by: { $0.key.rawValue < $1.key.rawValue }).first?.key.name
        }
        let sortedTiers = definition.tiers.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        for (tier, _) in sortedTiers {
            if tier.rawValue > currentTier.rawValue {
                return tier.name
            }
        }
        return nil
    }

    private var progressPercent: Double {
        guard let nextReq = nextTierRequirement else { return 1.0 }
        return min(Double(progress.currentValue) / Double(nextReq), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(definition.icon)
                    .font(.system(size: 26))
                    .grayscale(isUnlocked ? 0 : 0.6)

                Spacer()

                if let tier = progress.highestTierAchieved {
                    Text(tier.name)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(tier == .gold || tier == .platinum ? SwissColors.black : SwissColors.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(tier.color)
                }
            }

            Text(definition.name)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .foregroundColor(colors.textPrimary)
                .lineLimit(1)

            // Progress display
            HStack(spacing: 4) {
                Text("\(progress.currentValue)")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(isUnlocked ? SwissColors.green : SwissColors.black)

                if let nextReq = nextTierRequirement {
                    Text("/\(nextReq)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(colors.textTertiary)
                }
            }

            // Progress bar with tier info
            if !isUnlocked || nextTierRequirement != nil {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(SwissColors.gray100)
                                .frame(height: 5)

                            Rectangle()
                                .fill(isUnlocked ? SwissColors.green : SwissColors.textTertiary)
                                .frame(width: geometry.size.width * CGFloat(progressPercent), height: 5)
                        }
                    }
                    .frame(height: 5)

                    if let nextTier = nextTierName {
                        Text("Next: \(nextTier)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(colors.textTertiary)
                    }
                }
            }

            // Description
            if let tier = progress.highestTierAchieved,
               let requirement = definition.tiers[tier] {
                Text(requirement.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .overlay(
            Rectangle()
                .stroke(isUnlocked ? SwissColors.green : SwissColors.gray, lineWidth: isUnlocked ? 2 : 1)
        )
        .background(isUnlocked ? SwissColors.greenLight : SwissColors.white)
    }
}

struct SwissLockedTile: View {
    @Environment(\.adaptiveColors) var colors
    let definition: AchievementDefinition

    private var firstTierRequirement: String {
        if let firstTier = definition.tiers.sorted(by: { $0.key.rawValue < $1.key.rawValue }).first {
            return firstTier.value.description
        }
        return "???"
    }

    private var firstTierName: String {
        if let firstTier = definition.tiers.sorted(by: { $0.key.rawValue < $1.key.rawValue }).first {
            return firstTier.key.name
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(definition.icon)
                .font(.system(size: 22))
                .grayscale(1)
                .opacity(0.4)

            Text(definition.name)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(colors.textTertiary)
                .lineLimit(1)

            Text(firstTierRequirement)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(SwissColors.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .padding(8)
        .overlay(
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundColor(SwissColors.textMuted)
        )
    }
}

// MARK: - Play Style Picker Sheet
struct SwissPlayStylePickerSheet: View {
    @Environment(\.adaptiveColors) var colors
    let sport: String
    @Binding var selectedStyle: String
    let onDismiss: () -> Void

    // Filter playstyles based on sport
    private var availableStyles: [PlayStyle] {
        switch sport.lowercased() {
        case "tennis":
            return [.baseliner, .aggressiveBaseliner, .serveAndVolley, .allCourt, .counterpuncher]
        case "pickleball":
            return [.dinker, .banger, .hybrid, .netPressure]
        case "padel":
            return [.defensive, .aggressiveFinisher, .controlPlacement]
        default:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(availableStyles, id: \.self) { style in
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            selectedStyle = style.rawValue
                            onDismiss()
                        }) {
                            HStack(spacing: 16) {
                                // Style icon
                                ZStack {
                                    Rectangle()
                                        .fill(selectedStyle == style.rawValue ? SwissColors.green.opacity(0.15) : SwissColors.gray100)
                                        .frame(width: 48, height: 48)

                                    Image(systemName: style.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(selectedStyle == style.rawValue ? SwissColors.green : colors.textPrimary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(style.rawValue)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(colors.textPrimary)

                                    Text(style.description)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colors.textSecondary)
                                }

                                Spacer()

                                if selectedStyle == style.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(SwissColors.green)
                                }
                            }
                            .padding(16)
                            .overlay(
                                Rectangle()
                                    .stroke(selectedStyle == style.rawValue ? SwissColors.green : SwissColors.gray200, lineWidth: selectedStyle == style.rawValue ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .background(colors.background)
            .navigationTitle("\(sport) Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(SwissColors.green)
                }
            }
        }
    }
}

#Preview {
    SwissProfileView()
        .environmentObject(AppData())
        .environmentObject(WatchConnectivityManager.shared)
        .environmentObject(AuthenticationManager.shared)
}
