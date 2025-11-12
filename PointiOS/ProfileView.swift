// ProfileView.swift - Fixed Pills Position
import SwiftUI

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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
            HistoryView(initialFilter: selectedSport)
                .environmentObject(watchConnectivity)
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // FIXED: Removed the 50pt Color.clear spacer that was causing the issue
                // Now pills start at appropriate position with just padding
                
                // Sport Filter Pills
                SportFilterPills(selectedSport: $selectedSport)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)  // Reasonable top padding instead of 50pt spacer
                    .padding(.bottom, 24)
                
                // Profile Card
                ProfileInfoCard(
                    isEditing: $isEditingProfile,
                    selectedSport: selectedSport
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Sport Distribution / Play Style
                if selectedSport == .all {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sport Distribution")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if watchConnectivity.receivedGames.isEmpty {
                            Text("No games played yet")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            SportDistributionView()
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                } else {
                    PlayStyleCard(
                        isEditing: $isEditingPlayStyle,
                        selectedSport: selectedSport
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Game Type Breakdown for selected sport
                    GameTypeBreakdownCard(selectedSport: selectedSport)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                // Achievements Section - only for "All"
                if selectedSport == .all {
                    ProfileAchievementsSection()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                
                // Recent Games
                RecentGamesSection(
                    selectedSport: selectedSport,
                    showingHistory: $showingHistory
                )
                
                // Bottom padding for tab bar
                Color.clear
                    .frame(height: 120)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

// Recent Games Section with proper navigation
struct RecentGamesSection: View {
    let selectedSport: SportFilter
    @Binding var showingHistory: Bool
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    
    private var recentGames: [WatchGameRecord] {
        Array(watchConnectivity.games(for: selectedSport).prefix(10))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Recent Games")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !watchConnectivity.receivedGames.isEmpty {
                    Button("View All") {
                        showingHistory = true
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 20)
            
            if recentGames.isEmpty {
                Text(selectedSport == .all ? "No games recorded yet" : "No \(selectedSport.rawValue) games recorded yet")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentGames) { game in
                        RecentGameRow(game: game)
                    }
                }
                .padding(.horizontal, 20)
                
                if watchConnectivity.games(for: selectedSport).count > 10 {
                    Button(action: { showingHistory = true }) {
                        Text("View All \(watchConnectivity.games(for: selectedSport).count) Games")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
    }
}

// Game Row with working detail view
struct RecentGameRow: View {
    let game: WatchGameRecord
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            if game.events != nil && !game.events!.isEmpty {
                showingDetail = true
            }
        }) {
            HStack(spacing: 16) {
                Text(game.sportEmoji)
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(game.sportType) • \(game.gameType)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(game.date, style: .relative)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        if game.events == nil || game.events!.isEmpty {
                            Text("• No details")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(game.scoreDisplay)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let winner = game.winner {
                        Circle()
                            .fill(winner == "You" ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
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
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("👤")
                                .font(.system(size: 40))
                                .opacity(0.6)
                        )
                    
                    VStack(alignment: .leading, spacing: 16) {
                        if isEditing {
                            TextField("Display Name", text: $appData.displayName)
                                .font(.system(size: 32, weight: .bold))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(appData.displayName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        HStack(spacing: 20) {
                            ProfileStatItem(
                                label: "L10",
                                value: getL10Stats(),
                                color: .accentColor
                            )
                            
                            ProfileStatItem(
                                label: "Win%",
                                value: getWinPercentage(),
                                color: .accentColor
                            )
                            
                            ProfileStatItem(
                                label: "Total",
                                value: getGamesCount(),
                                color: .accentColor
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isEditing.toggle() }) {
                        Text(isEditing ? "✓" : "✏️")
                            .font(.system(size: 20))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
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
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }
}

// MARK: - Game Type Breakdown Card - with Donut Chart
struct GameTypeBreakdownCard: View {
    let selectedSport: SportFilter
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager

    private var donutData: [DonutChartData] {
        let games = watchConnectivity.games(for: selectedSport)
        guard !games.isEmpty else { return [] }

        let singlesCount = games.filter { $0.gameType.lowercased().contains("singles") }.count
        let doublesCount = games.filter { $0.gameType.lowercased().contains("doubles") }.count

        var data: [DonutChartData] = []

        if singlesCount > 0 {
            data.append(DonutChartData(label: "Singles", value: Double(singlesCount), color: .blue))
        }
        if doublesCount > 0 {
            data.append(DonutChartData(label: "Doubles", value: Double(doublesCount), color: .purple))
        }

        return data
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
                DonutChart(
                    data: donutData,
                    centerText: "\(totalGames)",
                    size: 140,
                    lineWidth: 28
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}
