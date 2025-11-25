// ProfileView.swift - Fixed Pills Position
import SwiftUI
import LucideIcons

// Sport Filter Pills Component
struct SportFilterPills: View {
    @Binding var selectedSport: SportFilter
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileSportPill(
                title: "All",
                isSelected: selectedSport == .all,
                action: { selectedSport = .all }
            )
            
            ProfileSportPill(
                icon: "🥒",
                title: "PB",
                isSelected: selectedSport == .pickleball,
                action: { selectedSport = .pickleball }
            )
            
            ProfileSportPill(
                icon: "🎾",
                title: "Ten",
                isSelected: selectedSport == .tennis,
                action: { selectedSport = .tennis }
            )
            
            ProfileSportPill(
                icon: "🏓",
                title: "Pad",
                isSelected: selectedSport == .padel,
                action: { selectedSport = .padel }
            )
        }
    }
}

struct ProfileSportPill: View {
    var icon: String?
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Text(icon)
                        .font(.system(size: 16))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State private var isEditingProfile = false
    @State private var isEditingPlayStyle = false
    @State private var selectedSport: SportFilter = .all
    @State private var showingHistory = false
    @ObservedObject private var pro = ProEntitlements.shared
    
    var body: some View {
        NavigationView {
            ProfileContent(
                isEditingProfile: $isEditingProfile,
                isEditingPlayStyle: $isEditingPlayStyle,
                selectedSport: $selectedSport,
                showingHistory: $showingHistory
            )
            .environmentObject(appData)
            .environmentObject(watchConnectivity)
        }
        .fullScreenCover(isPresented: $showingHistory) {
            if pro.isPro {
                HistoryView(initialFilter: selectedSport)
                    .environmentObject(watchConnectivity)
            } else {
                UpgradeView()
            }
        }
    }
}

struct ProfileContent: View {
    @Binding var isEditingProfile: Bool
    @Binding var isEditingPlayStyle: Bool
    @Binding var selectedSport: SportFilter
    @Binding var showingHistory: Bool
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingUpgrade = false
    
    private let maxCardWidth: CGFloat = 448
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // FIXED: Removed the 50pt Color.clear spacer that was causing the issue
                // Now pills start at appropriate position with just padding
                
                // Sport Filter Pills
                SportFilterPills(selectedSport: $selectedSport)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                
                // Profile Card
                ProfileInfoCard(
                    isEditing: $isEditingProfile,
                    selectedSport: selectedSport
                )
                .frame(maxWidth: maxCardWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Sport Distribution / Play Style
                if selectedSport == .all {
                    Group {
                        if pro.isPro {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sport Distribution")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                if watchConnectivity.receivedGames.isEmpty {
                                    Text("No games played yet")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                } else {
                                    SportDistributionView()
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(.systemGray6))
                            )
                        } else {
                            LockedFeatureCard(
                                title: "Advanced Analytics",
                                description: "Unlock sport distribution, trend charts, and deeper breakdowns with Point Pro."
                            ) {
                                showingUpgrade = true
                            }
                        }
                    }
                    .frame(maxWidth: maxCardWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                } else {
                    PlayStyleCard(
                        isEditing: $isEditingPlayStyle,
                        selectedSport: selectedSport
                    )
                    .frame(maxWidth: maxCardWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // Game Type Breakdown for selected sport
                    Group {
                        if pro.isPro {
                            GameTypeBreakdownCard(selectedSport: selectedSport)
                        } else {
                            LockedFeatureCard(
                                title: "Breakdown Locked",
                                description: "Upgrade to Point Pro for detailed game-type insights and analytics."
                            ) {
                                showingUpgrade = true
                            }
                        }
                    }
                        .frame(maxWidth: maxCardWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }

                // Achievements Section - only for "All"
                if selectedSport == .all {
                    Group {
                        if pro.isPro {
                            ProfileAchievementsSection()
                        } else {
                            LockedFeatureCard(
                                title: "Achievements & Streaks",
                                description: "Unlock Point Pro to access achievements, streak tracking, and gamified goals."
                            ) {
                                showingUpgrade = true
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                        .frame(maxWidth: maxCardWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                
                // Recent Games
                RecentGamesSection(
                    selectedSport: selectedSport,
                    showingHistory: $showingHistory,
                    isPro: pro.isPro,
                    onLockedTap: { showingUpgrade = true }
                )
                .frame(maxWidth: maxCardWidth)
                .frame(maxWidth: .infinity)
                
                // Bottom padding for tab bar
                Color.clear
                    .frame(height: 96)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
        }
    }
}

// Recent Games Section with proper navigation
struct RecentGamesSection: View {
    let selectedSport: SportFilter
    @Binding var showingHistory: Bool
    let isPro: Bool
    let onLockedTap: () -> Void
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    
    private var recentGames: [WatchGameRecord] {
        Array(watchConnectivity.games(for: selectedSport).prefix(10))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Games")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !watchConnectivity.receivedGames.isEmpty {
                    Button("View All") {
                        if isPro {
                            showingHistory = true
                        } else {
                            onLockedTap()
                        }
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 0)
            
            if recentGames.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )
                    Text("No recent games")
                        .foregroundColor(.secondary)
                    Text("Your game history will appear here")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentGames) { game in
                        RecentGameRow(
                            game: game,
                            isPro: isPro,
                            onLockedTap: onLockedTap
                        )
                    }
                }
                .padding(.horizontal, 0)
                
                if watchConnectivity.games(for: selectedSport).count > 10 {
                    Button(action: {
                        if isPro {
                            showingHistory = true
                        } else {
                            onLockedTap()
                        }
                    }) {
                        Text("View All \(watchConnectivity.games(for: selectedSport).count) Games")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 0)
                    .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(.separator), lineWidth: 1)
                )
        )
    }
}

// Game Row with working detail view
struct RecentGameRow: View {
    let game: WatchGameRecord
    let isPro: Bool
    let onLockedTap: () -> Void
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            guard isPro else {
                onLockedTap()
                return
            }
            if game.events != nil && !game.events!.isEmpty {
                showingDetail = true
            }
        }) {
            HStack(spacing: 16) {
                // Icon box
                Text(game.sportEmoji)
                    .font(.system(size: 24))
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    )
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(game.sportType) • \(game.gameType)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text(game.date, style: .relative)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Score + dot
                HStack(spacing: 8) {
                    Text(game.scoreDisplay)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    if let winner = game.winner {
                        Circle()
                            .fill(winner == "You" ? Color(.systemGreen) : Color(.systemRed))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            GameDetailView(game: game)
        }
    }
}

// Profile Info Card
struct ProfileInfoCard: View {
    @Binding var isEditing: Bool
    let selectedSport: SportFilter
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
            
            Circle()
                .fill(overlayGlow)
                .frame(width: 180, height: 180)
                .blur(radius: 36)
                .offset(x: 64, y: -60)
                .allowsHitTesting(false)
            
            VStack(alignment: .leading, spacing: 12) {
                // Name + sport
                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Display Name", text: $appData.displayName)
                            .font(.system(size: 20, weight: .semibold))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(appData.displayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                // Member info + optional XP
                if selectedSport == .all {
                    HStack(spacing: 6) {
                        Text("Member since March 2023")
                            .font(.system(size: 13))
                            .foregroundColor(colorScheme == .dark ? Color(.systemGray) : Color(.darkGray))
                        
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(colorScheme == .dark ? Color(.systemGray2) : Color(.lightGray))
                        Text("2,175 XP")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
                
                // Sport rating badge
                if selectedSport != .all {
                    ratingBadge
                }
                
                // Stats grid
                HStack(spacing: 12) {
                    statCard(value: getL10Stats(), label: "L10")
                    statCard(value: getWinPercentage(), label: "Win%")
                    statCard(value: getGamesCount(), label: "Total")
                }
                .padding(.top, 12)
            }
            .padding(24)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 8, x: 0, y: 8)
    }
    
    private var cardGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.blue.opacity(0.20), Color(.systemGray6).opacity(0.08), Color(.black)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.white, Color(.systemGray6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.blue.opacity(0.30) : Color.blue.opacity(0.30)
    }
    
    private var overlayGlow: Color {
        colorScheme == .dark ? Color.blue.opacity(0.12) : Color.blue.opacity(0.20)
    }
    
    private var sportLabel: String {
        switch selectedSport {
        case .all: return ""
        case .pickleball: return "Pickleball"
        case .tennis: return "Tennis"
        case .padel: return "Padel"
        }
    }
    
    @ViewBuilder
    private var ratingBadge: some View {
        switch selectedSport {
        case .pickleball:
            badgeView(label: "DUPR", value: "3.45", primary: Color.green, tint: Color.green.opacity(0.3))
        case .tennis:
            badgeView(label: "UTR", value: "6.2", primary: Color.blue, tint: Color.blue.opacity(0.3))
        case .padel:
            badgeView(label: "Playtomic", value: "4.8", primary: Color.purple, tint: Color.purple.opacity(0.3))
        case .all:
            EmptyView()
        }
    }
    
    private func badgeView(label: String, value: String, primary: Color, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? primary.opacity(0.7) : primary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(primary.opacity(colorScheme == .dark ? 0.10 : 0.08))
                .overlay(
                    Capsule()
                        .stroke(tint, lineWidth: 1)
                )
        )
    }
    
    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(colorScheme == .dark ? Color(.systemGray2) : Color(.darkGray))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.12) : Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.25), lineWidth: 1)
                )
        )
    }
    
    private func getL10Stats() -> String {
        let games = watchConnectivity.games(for: selectedSport)
        let last10 = Array(games.prefix(10))
        let wins = last10.filter { $0.winner == "You" }.count
        let losses = last10.count - wins
        return "\(wins)-\(losses)"
    }
    
    private func getWinPercentage() -> String {
        let games = watchConnectivity.games(for: selectedSport)
        guard !games.isEmpty else { return "0%" }
        let wins = games.filter { $0.winner == "You" }.count
        let percentage = (Double(wins) / Double(games.count)) * 100
        return "\(Int(percentage))%"
    }
    
    private func getGamesCount() -> String {
        let games = watchConnectivity.games(for: selectedSport)
        return "\(games.count)"
    }
}

struct ProfileStatItem: View {
    let icon: LucideIcon
    let label: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            // Lucide Icon
            Image(icon: icon)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(statBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(colorScheme == .dark ? 0.5 : 0.25), lineWidth: 1)
                )
        )
    }
    
    private var statBackground: LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(colorScheme == .dark ? 0.25 : 0.18),
                color.opacity(colorScheme == .dark ? 0.08 : 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Game Type Breakdown Card - with Donut Chart
struct GameTypeBreakdownCard: View {
    let selectedSport: SportFilter
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager

    private var donutData: [DonutChartData] {
        let games = watchConnectivity.games(for: selectedSport)
        let singlesCount = games.filter { $0.gameType.lowercased().contains("singles") }.count
        let doublesCount = games.filter { $0.gameType.lowercased().contains("doubles") }.count

        return [
            DonutChartData(label: "Singles", value: Double(singlesCount), color: .blue),
            DonutChartData(label: "Doubles", value: Double(doublesCount), color: .purple)
        ]
    }

    private var totalGames: Int {
        watchConnectivity.games(for: selectedSport).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game Types")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            if donutData.isEmpty {
                Text("No games played yet")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                HStack {
                    Spacer()
                    DonutChart(
                        data: donutData,
                        centerText: "\(totalGames)",
                        size: 140,
                        lineWidth: 28
                    )
                    Spacer()
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}
