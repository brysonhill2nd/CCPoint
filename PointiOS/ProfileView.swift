// ProfileView.swift - Fixed Pills Position
import SwiftUI
import Lucide

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
    @State private var showColorPicker = false
    
    var body: some View {
        NavigationView {
            ProfileContent(
                isEditingProfile: $isEditingProfile,
                isEditingPlayStyle: $isEditingPlayStyle,
                selectedSport: $selectedSport,
                showingHistory: $showingHistory,
                showColorPicker: $showColorPicker
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
    @Binding var showColorPicker: Bool
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
                        HStack {
                            Image(icon: .trendingUp)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.secondary)

                            Text("Sport Distribution")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)

                            Spacer()

                            // Color Picker Button
                            Button(action: { showColorPicker.toggle() }) {
                                Image(icon: .palette)
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray5))
                                    )
                            }
                        }

                        // Color Scheme Picker with Gradients
                        if showColorPicker {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(ChartColorScheme.allCases, id: \.self) { scheme in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            appData.chartColorScheme = scheme
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            // Gradient Preview
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: scheme.previewColors),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(height: 40)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                )

                                            Text(scheme.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(appData.chartColorScheme == scheme ? Color.blue.opacity(0.1) : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(appData.chartColorScheme == scheme ? Color.blue : Color(.systemGray4), lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .transition(.opacity)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appData.chartColorScheme)
                        }

                        if watchConnectivity.receivedGames.isEmpty {
                            VStack(spacing: 12) {
                                Image(icon: .trendingUp)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.secondary)
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(Color(.systemGray5))
                                    )

                                Text("No games played yet")
                                    .font(.system(size: 17))
                                    .foregroundColor(.secondary)

                                Text("Start playing to see your stats")
                                    .font(.system(size: 14))
                                    .foregroundColor(.tertiary)
                            }
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
                VStack(spacing: 12) {
                    Image(icon: .trophy)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.secondary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )

                    Text("No recent games")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)

                    Text("Your game history will appear here")
                        .font(.system(size: 14))
                        .foregroundColor(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background with gradient overlay
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.1),
                            Color(.systemGray6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                )

            // Gradient accent circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.2),
                            Color.clear
                        ]),
                        center: .topTrailing,
                        startRadius: 1,
                        endRadius: 200
                    )
                )
                .frame(width: 200, height: 200)
                .offset(x: 80, y: -80)
                .blur(radius: 40)

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Avatar with gradient background
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.2),
                                        Color(.systemGray5)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.3), lineWidth: 1)
                            )

                        Image(icon: .user)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Color.blue.opacity(colorScheme == .dark ? 0.6 : 0.8))

                        // Edit badge
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: { isEditing.toggle() }) {
                                    Image(icon: .pencil)
                                        .resizable()
                                        .frame(width: 14, height: 14)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(
                                            Circle()
                                                .fill(Color.blue)
                                                .shadow(color: Color.blue.opacity(0.5), radius: 4, x: 0, y: 2)
                                        )
                                }
                                .offset(x: 8, y: 8)
                            }
                        }
                        .frame(width: 80, height: 80)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if isEditing {
                            TextField("Display Name", text: $appData.displayName)
                                .font(.system(size: 24, weight: .bold))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(appData.displayName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Text(selectedSport == .all ? "All Sports" : selectedSport == .pickleball ? "Pickleball" : selectedSport == .tennis ? "Tennis" : "Padel")
                            .font(.system(size: 15))
                            .foregroundColor(.blue)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Stats Grid with backdrop blur effect
                HStack(spacing: 12) {
                    ProfileStatBox(
                        value: getL10Stats(),
                        label: "L10",
                        colorScheme: colorScheme
                    )

                    ProfileStatBox(
                        value: getWinPercentage(),
                        label: "Win%",
                        colorScheme: colorScheme
                    )

                    ProfileStatBox(
                        value: getGamesCount(),
                        label: "Total",
                        colorScheme: colorScheme
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity)
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
        .frame(minWidth: 50)
    }
}

// Profile Stat Box with backdrop blur effect
struct ProfileStatBox: View {
    let value: String
    let label: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark
                        ? Color(.systemGray6).opacity(0.7)
                        : Color.white.opacity(0.7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Game Type Breakdown Card - with Donut Chart
struct GameTypeBreakdownCard: View {
    let selectedSport: SportFilter
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var appData: AppData
    @Environment(\.colorScheme) var systemColorScheme

    private var donutData: [DonutChartData] {
        let games = watchConnectivity.games(for: selectedSport)
        guard !games.isEmpty else { return [] }

        let singlesCount = games.filter { $0.gameType.lowercased().contains("singles") }.count
        let doublesCount = games.filter { $0.gameType.lowercased().contains("doubles") }.count

        let colorScheme = appData.chartColorScheme
        var data: [DonutChartData] = []

        // Use sport-specific colors for singles/doubles
        if singlesCount > 0 {
            let color = getSportColor(isDark: systemColorScheme == .dark, isLight: false)
            data.append(DonutChartData(label: "Singles", value: Double(singlesCount), color: color))
        }
        if doublesCount > 0 {
            let color = getSportColor(isDark: systemColorScheme == .dark, isLight: true)
            data.append(DonutChartData(label: "Doubles", value: Double(doublesCount), color: color))
        }

        return data
    }

    private func getSportColor(isDark: Bool, isLight: Bool) -> Color {
        let colorScheme = appData.chartColorScheme

        switch selectedSport {
        case .pickleball:
            return isLight ? colorScheme.pickleballLightColor : colorScheme.pickleballColor
        case .tennis:
            return isLight ? colorScheme.tennisLightColor : colorScheme.tennisColor
        case .padel:
            return isLight ? colorScheme.padelLightColor : colorScheme.padelColor
        case .all:
            return isDark ? (isLight ? Color(.systemGray3) : Color(.systemGray4)) : (isLight ? Color(.systemGray5) : Color(.systemGray6))
        }
    }

    private var totalGames: Int {
        watchConnectivity.games(for: selectedSport).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(icon: .trophy)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)

                Text("Game Types")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()
            }

            if donutData.isEmpty {
                VStack(spacing: 12) {
                    Image(icon: .trophy)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.secondary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )

                    Text("No games played yet")
                        .font(.system(size: 17))
                        .foregroundColor(.secondary)

                    Text("Start playing to see your stats")
                        .font(.system(size: 14))
                        .foregroundColor(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
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
