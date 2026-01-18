//
//  SwissStatisticsView.swift
//  PointiOS
//
//  Swiss Minimalist Statistics/Analytics View
//

import SwiftUI

struct SwissStatisticsView: View {
    @Environment(\.adaptiveColors) var colors
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State private var selectedSport: SportFilter = .all
    @State private var selectedTimeRange: TimeRange = .last7Days
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingProSheet = false

    // Animation states
    @State private var headerVisible = false
    @State private var controlsVisible = false
    @State private var statsVisible = false
    @State private var bestsVisible = false
    @State private var streakVisible = false

    enum TimeRange: String, CaseIterable {
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case allTime = "All Time"
    }

    private var filteredGames: [WatchGameRecord] {
        let sportFiltered = watchConnectivity.games(for: selectedSport)

        let calendar = Calendar.current
        let now = Date()

        switch selectedTimeRange {
        case .last7Days:
            let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return sportFiltered.filter { $0.date >= cutoff }
        case .last30Days:
            let cutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return sportFiltered.filter { $0.date >= cutoff }
        case .allTime:
            return sportFiltered
        }
    }

    private var hasFilteredGames: Bool {
        !filteredGames.isEmpty
    }

    private var stats: StatsData {
        let games = filteredGames
        let wins = games.filter { $0.winner == "You" }.count
        let winRate = games.isEmpty ? 0 : Double(wins) / Double(games.count)
        let totalTime = games.reduce(0) { $0 + $1.elapsedTime } / 3600

        return StatsData(
            winRate: Int(winRate * 100),
            games: games.count,
            time: totalTime,
            wins: wins,
            losses: games.count - wins
        )
    }

    struct StatsData {
        let winRate: Int
        let games: Int
        let time: Double
        let wins: Int
        let losses: Int
    }

    // MARK: - All Time Bests (Computed from real data, per sport)
    private var allTimeBests: AllTimeBests {
        // Filter by selected sport (but not time range - these are "all time" for this sport)
        let sportGames = watchConnectivity.games(for: selectedSport)

        // Longest win streak
        var currentStreak = 0
        var maxStreak = 0
        for game in sportGames.sorted(by: { $0.date < $1.date }) {
            if game.winner == "You" {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }

        // Hardest shot (from shots data - using absoluteMagnitude which represents peak G-force)
        var hardestShot: Double = 0
        for game in sportGames {
            if let shots = game.shots {
                for shot in shots {
                    hardestShot = max(hardestShot, shot.absoluteMagnitude)
                }
            }
        }

        // Biggest blowout (largest point differential in a win)
        var biggestBlowout: (player: Int, opponent: Int) = (0, 0)
        var maxDiff = 0
        for game in sportGames where game.winner == "You" {
            let diff = game.player1Score - game.player2Score
            if diff > maxDiff {
                maxDiff = diff
                biggestBlowout = (game.player1Score, game.player2Score)
            }
        }

        // Longest game
        let longestGame = sportGames.max(by: { $0.elapsedTime < $1.elapsedTime })?.elapsedTime ?? 0

        return AllTimeBests(
            longestStreak: maxStreak,
            hardestShot: hardestShot,
            biggestBlowout: biggestBlowout,
            longestGameTime: longestGame
        )
    }

    struct AllTimeBests {
        let longestStreak: Int
        let hardestShot: Double
        let biggestBlowout: (player: Int, opponent: Int)
        let longestGameTime: TimeInterval

        var longestStreakDisplay: String {
            longestStreak > 0 ? "\(longestStreak) Wins" : "--"
        }

        var hardestShotDisplay: String {
            hardestShot > 0 ? String(format: "%.1fg", hardestShot) : "--"
        }

        var biggestBlowoutDisplay: String {
            biggestBlowout.player > 0 ? "\(biggestBlowout.player)-\(biggestBlowout.opponent)" : "--"
        }

        var longestGameDisplay: String {
            guard longestGameTime > 0 else { return "--" }
            let hours = Int(longestGameTime) / 3600
            let minutes = (Int(longestGameTime) % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }

    // MARK: - Current Streak (Computed, per sport)
    private var currentWinStreak: Int {
        var streak = 0
        let sportGames = watchConnectivity.games(for: selectedSport)
        for game in sportGames {
            if game.winner == "You" {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private var sportLabel: String {
        switch selectedSport {
        case .all: return "All Sports"
        case .tennis: return "Tennis"
        case .pickleball: return "Pickleball"
        case .padel: return "Padel"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerSection
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : -20)

                // Controls
                controlsSection
                    .opacity(controlsVisible ? 1 : 0)

                // Key Stats Grid
                keyStatsGrid
                    .opacity(statsVisible ? 1 : 0)
                    .offset(y: statsVisible ? 0 : 20)

                // Personal Bests
                personalBestsSection
                    .opacity(bestsVisible ? 1 : 0)
                    .offset(y: bestsVisible ? 0 : 20)

                // Streak Tracker
                streakTrackerSection
                    .opacity(streakVisible ? 1 : 0)
                    .offset(y: streakVisible ? 0 : 20)

                // Collapsible Sections
                collapsibleSections

                Color.clear.frame(height: 100)
            }
        }
        .background(colors.background)
        .onAppear {
            animateIn()
        }
        .sheet(isPresented: $showingProSheet) {
            UpgradeView()
        }
    }

    private func animateIn() {
        withAnimation(SwissAnimation.gentle) {
            headerVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.1)) {
            controlsVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.2)) {
            statsVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.3)) {
            bestsVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.4)) {
            streakVisible = true
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Statistics")
                .font(.system(size: 32, weight: .bold))
                .tracking(-1)
                .foregroundColor(colors.textPrimary)

            Text("Your Performance Insights")
                .font(SwissTypography.monoLabel(12))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundColor(colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 32)
    }

    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Time Range Dropdown
            HStack {
                Spacer()
                Menu {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            selectedTimeRange = range
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedTimeRange.rawValue)
                            .font(SwissTypography.monoLabel(12))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(colors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(colors.textPrimary)
                    }
                    .padding(.bottom, 4)
                    .overlay(
                        Rectangle()
                            .fill(SwissColors.black)
                            .frame(height: 1),
                        alignment: .bottom
                    )
                }
            }

            // Sport Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SwissFilterPill(title: "All Sports", isSelected: selectedSport == .all) {
                        HapticManager.shared.selection()
                        withAnimation(SwissAnimation.snappy) {
                            selectedSport = .all
                        }
                    }
                    SwissFilterPill(icon: "🎾", title: "Tennis", isSelected: selectedSport == .tennis) {
                        HapticManager.shared.selection()
                        withAnimation(SwissAnimation.snappy) {
                            selectedSport = .tennis
                        }
                    }
                    SwissFilterPill(icon: "🥒", title: "Pickleball", isSelected: selectedSport == .pickleball) {
                        HapticManager.shared.selection()
                        withAnimation(SwissAnimation.snappy) {
                            selectedSport = .pickleball
                        }
                    }
                    SwissFilterPill(icon: "🏓", title: "Padel", isSelected: selectedSport == .padel) {
                        HapticManager.shared.selection()
                        withAnimation(SwissAnimation.snappy) {
                            selectedSport = .padel
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Key Stats Grid
    private var keyStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Win Rate
            SwissStatCard(
                label: "Win Rate",
                value: "\(stats.winRate)%",
                trend: stats.winRate > 50 ? "+5%" : nil,
                trendPositive: true
            )
            .pressEffect(scale: 0.98, haptic: false)

            // Games
            SwissStatCard(
                label: "Games",
                value: "\(stats.games)",
                trend: stats.games > 10 ? "+12" : nil,
                trendPositive: true
            )
            .pressEffect(scale: 0.98, haptic: false)

            // Time
            SwissStatCard(
                label: "Time",
                value: String(format: "%.1fh", stats.time),
                trend: nil,
                trendPositive: true
            )
            .pressEffect(scale: 0.98, haptic: false)

            // Record
            SwissStatCard(
                label: "Record",
                value: "\(stats.wins)-\(stats.losses)",
                trend: stats.wins > stats.losses ? "+2" : nil,
                trendPositive: stats.wins > stats.losses
            )
            .pressEffect(scale: 0.98, haptic: false)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Personal Bests Section
    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("🏆")
                    .font(.system(size: 18))
                Text("\(sportLabel) Bests")
                    .font(SwissTypography.monoLabel(12))
                    .textCase(.uppercase)
                    .tracking(1)
                    .fontWeight(.bold)
                    .foregroundColor(colors.textPrimary)

                Spacer()
            }

            if watchConnectivity.games(for: selectedSport).isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Text("No \(sportLabel.lowercased()) games yet")
                        .font(.system(size: 14))
                        .foregroundColor(colors.textSecondary)
                    Text("Play some games to see your personal bests")
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(colors.textMuted)
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    SwissPersonalBestCard(
                        icon: "flame",
                        label: "Longest Streak",
                        value: allTimeBests.longestStreakDisplay,
                        isHighlighted: allTimeBests.longestStreak > 0
                    )
                    .pressEffect(scale: 0.97, haptic: false)
                    .staggeredAppear(index: 0, total: 4)

                    SwissPersonalBestCard(
                        icon: "bolt",
                        label: "Hardest Shot",
                        value: allTimeBests.hardestShotDisplay,
                        isHighlighted: allTimeBests.hardestShot > 0
                    )
                    .pressEffect(scale: 0.97, haptic: false)
                    .staggeredAppear(index: 1, total: 4)

                    SwissPersonalBestCard(
                        icon: "target",
                        label: "Biggest Blowout",
                        value: allTimeBests.biggestBlowoutDisplay,
                        isHighlighted: allTimeBests.biggestBlowout.player > 0
                    )
                    .pressEffect(scale: 0.97, haptic: false)
                    .staggeredAppear(index: 2, total: 4)

                    SwissPersonalBestCard(
                        icon: "clock",
                        label: "Longest Game",
                        value: allTimeBests.longestGameDisplay,
                        isHighlighted: allTimeBests.longestGameTime > 0
                    )
                    .pressEffect(scale: 0.97, haptic: false)
                    .staggeredAppear(index: 3, total: 4)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Streak Tracker Section
    private var streakTrackerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Streak Tracker")
                .font(SwissTypography.monoLabel(12))
                .textCase(.uppercase)
                .tracking(1)
                .fontWeight(.bold)
                .foregroundColor(colors.textPrimary)

            // Current Streak Card
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentWinStreak > 0 ? "Current Streak" : "No Active Streak")
                            .font(SwissTypography.monoLabel(10))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(currentWinStreak > 0 ? SwissColors.green : SwissColors.gray400)

                        Text("\(currentWinStreak)")
                            .font(.system(size: 40, weight: .bold))
                            .tracking(-2)
                            .foregroundColor(colors.textPrimary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Best Streak")
                            .font(SwissTypography.monoLabel(9))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(colors.textSecondary)

                        Text("\(allTimeBests.longestStreak)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(currentWinStreak >= allTimeBests.longestStreak && currentWinStreak > 0 ? SwissColors.green : SwissColors.black)
                    }
                }
                .padding(20)
                .background(colors.background)
                .overlay(
                    Rectangle()
                        .stroke(currentWinStreak > 0 ? SwissColors.black : SwissColors.gray, lineWidth: currentWinStreak > 0 ? 2 : 1)
                )
            }

            // Next Record
            if allTimeBests.longestStreak > 0 {
                let winsNeeded = max(0, allTimeBests.longestStreak - currentWinStreak + 1)
                HStack {
                    HStack(spacing: 12) {
                        Text("🏆")
                            .font(.system(size: 20))
                            .grayscale(currentWinStreak >= allTimeBests.longestStreak ? 0 : 0.5)
                            .opacity(currentWinStreak >= allTimeBests.longestStreak ? 1 : 0.5)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentWinStreak >= allTimeBests.longestStreak ? "New Record!" : "Record Breaker")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(currentWinStreak >= allTimeBests.longestStreak ? SwissColors.green : SwissColors.gray500)

                            Text(currentWinStreak >= allTimeBests.longestStreak ? "Keep the streak going!" : "\(winsNeeded) win\(winsNeeded == 1 ? "" : "s") to beat record")
                                .font(SwissTypography.monoLabel(9))
                                .foregroundColor(colors.textSecondary)
                        }
                    }

                    Spacer()

                    Text("TARGET: \(allTimeBests.longestStreak + 1)")
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.textSecondary)
                }
                .padding(16)
                .background(SwissColors.gray50)
                .overlay(
                    Rectangle()
                        .stroke(SwissColors.gray, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Collapsible Sections
    private var collapsibleSections: some View {
        VStack(spacing: 0) {
            // Activity This Week
            SwissCollapsibleSection(title: "Activity This Week") {
                activityChart
            }
            .padding(.horizontal, 24)

            // Performance Breakdown
            SwissCollapsibleSection(title: "Performance Breakdown") {
                performanceBreakdown
            }
            .padding(.horizontal, 24)

            // Shot Distribution
            SwissCollapsibleSection(title: "Shot Distribution") {
                shotDistribution
            }
            .padding(.horizontal, 24)

            // Next Milestones
            SwissCollapsibleSection(title: "Next Milestones") {
                milestonesSection
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Activity Chart (Real Data)
    private var weeklyActivityData: (hours: [CGFloat], total: Double, labels: [String]) {
        let calendar = Calendar.current
        let today = Date()

        // Get the start of this week (Sunday or Monday based on locale)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

        var dailyMinutes: [Double] = Array(repeating: 0, count: 7)
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

        // Sum up play time for each day of the week
        for game in watchConnectivity.receivedGames {
            guard let daysDiff = calendar.dateComponents([.day], from: startOfWeek, to: game.date).day,
                  daysDiff >= 0 && daysDiff < 7 else { continue }
            dailyMinutes[daysDiff] += game.elapsedTime / 60.0
        }

        let maxMinutes = dailyMinutes.max() ?? 1
        let normalizedHeights = dailyMinutes.map { CGFloat($0 / max(maxMinutes, 1)) * 100 }
        let totalHours = dailyMinutes.reduce(0, +) / 60.0

        return (normalizedHeights, totalHours, dayLabels)
    }

    private var activityChart: some View {
        let data = weeklyActivityData

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Total: \(String(format: "%.1fh", data.total))")
                    .font(SwissTypography.monoLabel(9))
                    .foregroundColor(colors.textSecondary)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.labels.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 4) {
                        AnimatedChartBar(
                            height: max(data.hours[index], 4), // Minimum 4pt for visibility
                            maxHeight: 100,
                            color: SwissColors.green,
                            delay: Double(index) * 0.05
                        )

                        Text(day)
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weekly activity chart showing \(String(format: "%.1f", data.total)) total hours this week")
        }
    }

    // MARK: - Performance Breakdown
    private var performanceBreakdown: some View {
        let breakdown = performanceBreakdownData

        return VStack(spacing: 12) {
            if breakdown.isEmpty {
                Text("Play games with locations to see performance breakdown")
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(Array(breakdown.enumerated()), id: \.offset) { index, item in
                    SwissPerformanceRow(
                        emoji: index == 0 ? "🥇" : (index == 1 ? "🥈" : "🥉"),
                        title: item.name,
                        winRate: "\(item.winRate)%",
                        isHighlighted: index == 0
                    )
                }
            }
        }
    }

    // MARK: - Shot Distribution (Real Data)
    private var shotDistributionData: [(type: String, count: Int, percentage: Double)] {
        var shotCounts: [String: Int] = [
            "Serve": 0,
            "Power Shots": 0,
            "Touch Shots": 0,
            "Volleys": 0,
            "Overheads": 0
        ]

        for game in filteredGames {
            if let shots = game.shots {
                for shot in shots {
                    switch shot.type {
                    case .serve:
                        shotCounts["Serve", default: 0] += 1
                    case .powerShot:
                        shotCounts["Power Shots", default: 0] += 1
                    case .touchShot:
                        shotCounts["Touch Shots", default: 0] += 1
                    case .volley:
                        shotCounts["Volleys", default: 0] += 1
                    case .overhead:
                        shotCounts["Overheads", default: 0] += 1
                    case .unknown:
                        break // Don't count unknown shots
                    }
                }
            }
        }

        let total = Double(shotCounts.values.reduce(0, +))
        guard total > 0 else { return [] }

        return shotCounts
            .filter { $0.value > 0 } // Only show categories with data
            .map { (type: $0.key, count: $0.value, percentage: Double($0.value) / total) }
            .sorted { $0.percentage > $1.percentage }
    }

    private var shotDistribution: some View {
        let data = shotDistributionData
        let hasRealData = data.first?.count ?? 0 > 0

        return VStack(spacing: 12) {
            if !hasRealData {
                Text("Play more games to see shot distribution")
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }

            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                SwissAnimatedProgressRow(
                    title: item.type,
                    value: item.percentage,
                    delay: Double(index) * 0.1
                )
            }
        }
    }

    private var performanceBreakdownData: [(name: String, winRate: Int, total: Int)] {
        guard hasFilteredGames else { return [] }

        var locationStats: [String: (wins: Int, total: Int)] = [:]
        for game in filteredGames {
            guard let location = game.location?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !location.isEmpty else { continue }
            let current = locationStats[location, default: (0, 0)]
            let wins = current.wins + (game.winner == "You" ? 1 : 0)
            locationStats[location] = (wins, current.total + 1)
        }

        var rows: [(name: String, winRate: Int, total: Int)] = locationStats.map { name, stats in
            let winRate = stats.total > 0 ? Int((Double(stats.wins) / Double(stats.total)) * 100) : 0
            return (name: name, winRate: winRate, total: stats.total)
        }

        rows.sort { lhs, rhs in
            if lhs.winRate == rhs.winRate {
                return lhs.total > rhs.total
            }
            return lhs.winRate > rhs.winRate
        }

        return Array(rows.prefix(3))
    }

    // MARK: - Milestones Section (Real Data, per sport)
    private var milestonesData: [(title: String, progress: String, value: Double)] {
        let sportGames = watchConnectivity.games(for: selectedSport)
        let wins = sportGames.filter { $0.winner == "You" }.count
        let totalGames = sportGames.count

        var milestones: [(title: String, progress: String, value: Double)] = []

        // Milestone 1: Win count milestones (10, 25, 50, 100, 250, 500, 1000)
        let winMilestones = [10, 25, 50, 100, 250, 500, 1000]
        if let nextWinMilestone = winMilestones.first(where: { $0 > wins }) {
            let progress = Double(wins) / Double(nextWinMilestone)
            milestones.append((
                title: "\(nextWinMilestone) Wins",
                progress: "\(wins)/\(nextWinMilestone) Wins",
                value: progress
            ))
        }

        // Milestone 2: Games played milestones
        let gameMilestones = [10, 25, 50, 100, 250, 500]
        if let nextGameMilestone = gameMilestones.first(where: { $0 > totalGames }) {
            let progress = Double(totalGames) / Double(nextGameMilestone)
            milestones.append((
                title: "\(nextGameMilestone) Games Club",
                progress: "\(totalGames)/\(nextGameMilestone) Games",
                value: progress
            ))
        }

        // Milestone 3: Current streak to beat record
        let targetStreak = allTimeBests.longestStreak + 1
        let progress = Double(currentWinStreak) / Double(max(targetStreak, 1))
        milestones.append((
            title: "Streak Record",
            progress: "\(currentWinStreak)/\(targetStreak) Win Streak",
            value: min(progress, 1.0)
        ))

        return milestones
    }

    private var milestonesSection: some View {
        let data = milestonesData

        return VStack(spacing: 16) {
            if data.isEmpty {
                Text("Play some games to unlock milestones!")
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(Array(data.enumerated()), id: \.offset) { _, milestone in
                    SwissMilestoneRow(
                        title: milestone.title,
                        progress: milestone.progress,
                        value: milestone.value
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SwissStatCard: View {
    @Environment(\.adaptiveColors) var colors
    let label: String
    let value: String
    var trend: String? = nil
    var trendPositive: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(SwissTypography.monoLabel(9))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .tracking(-1)
                .foregroundColor(colors.textPrimary)

            if let trend = trend {
                Text(trend)
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(trendPositive ? SwissColors.green : SwissColors.red)
            } else {
                Text("-")
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(colors.textSecondary)
            }
        }
        .frame(height: 96)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            Rectangle()
                .stroke(SwissColors.gray, lineWidth: 1)
        )
    }
}

struct SwissPersonalBestCard: View {
    @Environment(\.adaptiveColors) var colors
    let icon: String
    let label: String
    let value: String
    var isHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isHighlighted ? SwissColors.green : SwissColors.gray400)
                    .opacity(0.5)
            }

            Text(label)
                .font(SwissTypography.monoLabel(9))
                .foregroundColor(isHighlighted ? SwissColors.green : SwissColors.gray500)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .tracking(-1)
                .foregroundColor(colors.textPrimary)
        }
        .padding(16)
        .background(SwissColors.gray.opacity(0.2))
        .overlay(
            Rectangle()
                .stroke(isHighlighted ? SwissColors.green : SwissColors.gray, lineWidth: 1)
        )
    }
}

struct SwissPerformanceRow: View {
    @Environment(\.adaptiveColors) var colors
    let emoji: String
    let title: String
    let winRate: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text("\(emoji) \(title)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(colors.textPrimary)

            Spacer()

            Text(winRate)
                .font(SwissTypography.monoLabel(9))
                .foregroundColor(isHighlighted ? SwissColors.green : SwissColors.gray400)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isHighlighted ? SwissColors.green.opacity(0.1) : SwissColors.gray50)
        }
        .padding(12)
        .overlay(
            Rectangle()
                .stroke(SwissColors.gray, lineWidth: 1)
        )
    }
}

struct SwissProgressRow: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(colors.textPrimary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(SwissColors.green)
            }

            SwissProgressBar(value: value, foregroundColor: SwissColors.green)
        }
    }
}

struct SwissAnimatedProgressRow: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    let value: Double
    var delay: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(colors.textPrimary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(SwissColors.green)
            }

            AnimatedProgressBar(value: value, foregroundColor: SwissColors.green, delay: delay)
        }
    }
}

struct SwissMilestoneRow: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    let progress: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(colors.textPrimary)
                Spacer()
                Text(progress)
                    .font(SwissTypography.monoLabel(9))
                    .foregroundColor(SwissColors.green)
            }

            SwissProgressBar(value: value, foregroundColor: SwissColors.green)
        }
    }
}

#Preview {
    SwissStatisticsView()
        .environmentObject(WatchConnectivityManager.shared)
}
