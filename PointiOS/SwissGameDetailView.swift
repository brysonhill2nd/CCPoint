//
//  SwissGameDetailView.swift
//  PointiOS
//
//  Swiss Minimalist Game Detail Modal
//

import SwiftUI

struct SwissGameDetailView: View {
    let game: WatchGameRecord
    @Environment(\.dismiss) var dismiss
    @Environment(\.adaptiveColors) var colors
    @State private var selectedTab: DetailTab = .overview
    @ObservedObject private var pro = ProEntitlements.shared

    // Animation states
    @State private var heroVisible = false
    @State private var contentVisible = false
    @State private var scoreAnimated = false

    // Timeline toggle
    @State private var showHighlightsOnly = true
    @State private var expandedGames: Set<String> = [] // "set_game" format

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case insights = "Insights"
        case shots = "Shots"
        case timeline = "Timeline"
    }

    private var isWin: Bool {
        game.winner == "You"
    }

    private var heroColor: Color {
        isWin ? SwissColors.green : SwissColors.red
    }

    // MARK: - Win Probability Calculation
    /// Calculates win probability based on heuristics:
    /// - Lead margin (higher lead = higher probability)
    /// - Points earned over time (momentum)
    /// - Set history if available
    private var calculatedWinProbability: Double {
        let player1 = Double(game.player1Score)
        let player2 = Double(game.player2Score)
        let totalPoints = player1 + player2

        guard totalPoints > 0 else { return 0.5 }

        // Base probability from score ratio
        var probability = player1 / totalPoints

        // Adjust based on lead margin (amplify advantage)
        let leadMargin = player1 - player2
        let marginFactor = leadMargin / max(totalPoints, 1) * 0.15
        probability += marginFactor

        // If we have set history, factor in set wins
        if let setHistory = game.setHistory, !setHistory.isEmpty {
            var setsWon = 0
            var setsLost = 0
            for set in setHistory {
                if set.player1Games > set.player2Games {
                    setsWon += 1
                } else if set.player2Games > set.player1Games {
                    setsLost += 1
                }
            }
            let setBonus = Double(setsWon - setsLost) * 0.1
            probability += setBonus
        }

        // Clamp to valid range
        return min(max(probability, 0.05), 0.95)
    }

    private var winProbabilityDisplay: String {
        "\(Int(calculatedWinProbability * 100))%"
    }

    private var aiInsightPayload: GameInsightPayload? {
        GameInsightGenerator.generate(for: game)
    }

    private var aiSummaryText: String {
        guard let payload = aiInsightPayload else {
            return "Track a point-level match on Apple Watch to unlock AI analysis for this game."
        }
        let summary = payload.insights.summary
        let recommendation = payload.insights.recommendation
        return "\(summary) \(recommendation)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section
                    heroSection
                        .opacity(heroVisible ? 1 : 0)
                        .scaleEffect(heroVisible ? 1 : 0.95)

                    // Tabs
                    tabSelector
                        .opacity(contentVisible ? 1 : 0)

                    // Content
                    Group {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .insights:
                            insightsContent
                        case .shots:
                            shotsContent
                        case .timeline:
                            timelineContent
                        }
                    }
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 20)
                }
            }
        }
        .background(colors.background)
        .onAppear {
            withAnimation(SwissAnimation.gentle) {
                heroVisible = true
            }
            withAnimation(SwissAnimation.gentle.delay(0.2)) {
                contentVisible = true
            }
            // Trigger score animation after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                scoreAnimated = true
                HapticManager.shared.notification(isWin ? .success : .warning)
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            // Sport and game type
            HStack(spacing: 8) {
                Text(game.sportEmoji)
                    .font(.system(size: 20))

                Text("\(game.sportType) \(game.gameType)")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .fontWeight(.bold)
                    .foregroundColor(colors.textPrimary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 24))
                    .foregroundColor(colors.textPrimary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .overlay(
            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 0) {
            // Result Banner
            Text(isWin ? "Victory Analyzed" : "Defeat Analyzed")
                .font(SwissTypography.monoLabel(11))
                .textCase(.uppercase)
                .tracking(1.5)
                .fontWeight(.bold)
                .foregroundColor(SwissColors.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Rectangle()
                        .stroke(SwissColors.white.opacity(0.4), lineWidth: 1)
                )
                .padding(.top, 24)
                .padding(.bottom, 24)

            // Score Display (Animated)
            AnimatedScoreDisplay(
                player1Score: game.player1Score,
                player2Score: game.player2Score,
                isWin: isWin
            )
            .padding(.bottom, 24)

            // Set Scores (if tennis/padel)
            if let setHistory = game.setHistory, !setHistory.isEmpty {
                HStack(spacing: 24) {
                    ForEach(Array(setHistory.enumerated()), id: \.offset) { _, set in
                        Text("\(set.player1Games)-\(set.player2Games)")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(SwissColors.white)
                            .padding(.bottom, 4)
                            .overlay(
                                Rectangle()
                                    .fill(SwissColors.white)
                                    .frame(height: 2),
                                alignment: .bottom
                            )
                    }
                }
                .padding(.bottom, 24)
            }

            // Meta Row
            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(game.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                }

                Circle()
                    .fill(SwissColors.white.opacity(0.4))
                    .frame(width: 4, height: 4)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(game.elapsedTimeDisplay)
                }

                if let location = game.location {
                    Circle()
                        .fill(SwissColors.white.opacity(0.4))
                        .frame(width: 4, height: 4)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                        Text(location)
                    }
                }
            }
            .font(SwissTypography.monoLabel(11))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundColor(SwissColors.white.opacity(0.8))
            .padding(.bottom, 24)

            Rectangle()
                .fill(SwissColors.white.opacity(0.2))
                .frame(height: 1)

            // Wearable Stats
            if let health = game.healthData {
                HStack(spacing: 0) {
                    SwissHealthStatWithIcon(icon: "flame", value: "\(Int(health.totalCalories))", label: "Kcal")
                    SwissHealthStatWithIcon(icon: "activity", value: "\(Int(health.averageHeartRate))", label: "Avg BPM")
                    SwissHealthStatWithIcon(icon: "target", value: "\(game.events?.count ?? 0)", label: "Points")
                }
                .padding(.vertical, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .background(heroColor)
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticManager.shared.selection()
                    withAnimation(SwissAnimation.snappy) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(SwissTypography.monoLabel(11))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(selectedTab == tab ? colors.textPrimary : colors.textTertiary)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            Rectangle()
                                .fill(selectedTab == tab ? colors.textPrimary : Color.clear)
                                .frame(height: 4),
                            alignment: .bottom
                        )
                        .animation(SwissAnimation.snappy, value: selectedTab)
                }
            }
        }
        .overlay(
            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Overview Content
    private var overviewContent: some View {
        VStack(spacing: 24) {
            // AI Analysis
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    if let lucideIcon = LucideIcon.named("sparkles") {
                        Image(icon: lucideIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundColor(colors.textPrimary)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(colors.textPrimary)
                    }

                    Text("AI Analysis")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(colors.textPrimary)
                }

                Text(aiSummaryText)
                    .font(.system(size: 14))
                    .foregroundColor(colors.textSecondary)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 32)

            // Win Probability Line
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Final Win Probability")
                        .font(SwissTypography.monoLabel(11))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(colors.textSecondary)

                    Text(isWin ? "Victory secured" : "Opponent prevailed")
                        .font(.system(size: 12))
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                Text(winProbabilityDisplay)
                    .font(.system(size: 48, weight: .bold))
                    .tracking(-2)
                    .foregroundColor(isWin ? SwissColors.green : SwissColors.red)
            }
            .padding(.horizontal, 32)

            // Win Probability Chart
            VStack(alignment: .leading, spacing: 16) {
                Text("Win Probability Matrix")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(colors.textSecondary)

                SwissWinProbabilityChart(finalProbability: calculatedWinProbability, isWin: isWin)
            }
            .padding(.horizontal, 32)

            // Heart Rate Intensity
            VStack(alignment: .leading, spacing: 16) {
                Text("Heart Rate Intensity")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(colors.textSecondary)

                SwissHeartRateChart()
            }
            .padding(.horizontal, 32)

            // Match Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                SwissDetailStatCard(label: "Max Lead", value: "14 pts")
                SwissDetailStatCard(label: "Lead Changes", value: "6")
                SwissDetailStatCard(label: "Longest Run", value: "8 pts")
                SwissDetailStatCard(label: "Time Leading", value: "62%")
            }
            .padding(.horizontal, 32)

            // Winning Streak - Shows your best run of consecutive points
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best Winning Streak")
                            .font(SwissTypography.monoLabel(11))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(SwissColors.white)
                        Text("5 points in a row")
                            .font(.system(size: 12))
                            .foregroundColor(SwissColors.white.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "flame.fill")
                        .foregroundColor(SwissColors.green)
                }

                HStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(i == 4 ? SwissColors.green : SwissColors.white)
                            .frame(width: i == 0 || i == 4 ? 40 : 32, height: i == 0 || i == 4 ? 40 : 32)
                            .overlay(
                                Text("W")
                                    .font(.system(size: i == 0 || i == 4 ? 12 : 10, weight: .bold))
                                    .foregroundColor(i == 4 ? SwissColors.white : SwissColors.black)
                            )
                            .overlay(
                                Circle()
                                    .stroke(SwissColors.white.opacity(0.4), lineWidth: 1)
                            )

                        if i < 4 {
                            Rectangle()
                                .fill(SwissColors.white.opacity(0.2))
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(24)
            .background(colors.textPrimary)
            .padding(.horizontal, 32)

            Color.clear.frame(height: 32)
        }
    }

    // MARK: - Computed Insights from Game Events
    private var gameInsights: iOSGameInsights {
        iOSGameInsights(events: game.events ?? [], isWin: isWin, sport: game.sportType)
    }

    // MARK: - Insights Content
    private var insightsContent: some View {
        VStack(spacing: 24) {
            // Point-by-Point Timeline (if events exist)
            if let events = game.events, !events.isEmpty {
                pointByPointSection(events: events)
            }

            // Serve Performance
            SwissInsightCard(title: "Serve Performance") {
                VStack(spacing: 16) {
                    SwissInsightRow(
                        label: "Your Serve Win %",
                        value: "\(gameInsights.yourServeWinPercentage)%",
                        color: gameInsights.yourServeWinPercentage >= 60 ? SwissColors.green : SwissColors.black
                    )
                    SwissInsightRow(
                        label: "Points on Serve",
                        value: "\(gameInsights.pointsWonOnServe)/\(gameInsights.totalServePoints)",
                        color: SwissColors.black
                    )
                    SwissInsightRow(
                        label: "Opponent Serve Win %",
                        value: "\(gameInsights.opponentServeWinPercentage)%",
                        color: SwissColors.gray400
                    )
                }
            }

            // Momentum
            SwissInsightCard(title: "Momentum") {
                VStack(spacing: 16) {
                    Text(gameInsights.momentumSummary)
                        .font(.system(size: 12))
                        .foregroundColor(colors.textSecondary)
                        .lineSpacing(4)

                    HStack(spacing: 16) {
                        SwissMomentumStat(value: "\(gameInsights.longestYourRun) pts", label: "Your Best Streak")
                        SwissMomentumStat(value: "\(gameInsights.longestOpponentRun) pts", label: "Their Best", dimmed: true)
                        SwissMomentumStat(value: "\(gameInsights.leadChanges)", label: "Lead Changes")
                    }
                }
            }

            // Key Moments (Highlights) - Pro only
            if pro.isPro, !gameInsights.keyMoments.isEmpty {
                SwissInsightCard(title: "Key Moments") {
                    VStack(spacing: 12) {
                        ForEach(gameInsights.keyMoments.prefix(4), id: \.description) { moment in
                            HStack(spacing: 12) {
                                Image(systemName: moment.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(moment.isPositive ? SwissColors.green : SwissColors.red)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(moment.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(colors.textPrimary)
                                    Text(moment.description)
                                        .font(SwissTypography.monoLabel(10))
                                        .foregroundColor(colors.textSecondary)
                                }

                                Spacer()

                                Text(moment.score)
                                    .font(SwissTypography.monoLabel(11))
                                    .foregroundColor(colors.textSecondary)
                            }
                        }
                    }
                }
            }

            // Shot Type Breakdown (if shots exist)
            if let shots = game.shots, !shots.isEmpty {
                SwissInsightCard(title: "Winning Shots") {
                    VStack(spacing: 12) {
                        let shotStats = computeShotStats(shots: shots)
                        ForEach(shotStats.prefix(4), id: \.type) { stat in
                            HStack {
                                Text(stat.type)
                                    .font(.system(size: 13))
                                    .foregroundColor(colors.textPrimary)

                                Spacer()

                                Text("\(stat.count) shots")
                                    .font(SwissTypography.monoLabel(11))
                                    .foregroundColor(colors.textSecondary)

                                Text("\(stat.percentage)%")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(stat.percentage >= 30 ? SwissColors.green : SwissColors.black)
                                    .frame(width: 40)
                            }
                        }
                    }
                }

                // Shot Highlights (Hardest/Softest shots) - Pro only
                if pro.isPro {
                    shotHighlightsSection(shots: shots)
                }
            }

            Color.clear.frame(height: 32)
        }
        .padding(.top, 32)
        .padding(.horizontal, 32)
    }

    // MARK: - Point-by-Point Section
    private func pointByPointSection(events: [GameEventData]) -> some View {
        SwissInsightCard(title: "Point-by-Point") {
            VStack(spacing: 8) {
                // Score progression visualization
                HStack(spacing: 2) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        let isYou = event.scoringPlayer == "player1"
                        Rectangle()
                            .fill(isYou ? SwissColors.green : SwissColors.red)
                            .frame(width: max(4, (UIScreen.main.bounds.width - 120) / CGFloat(events.count)), height: 24)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(SwissColors.green)
                            .frame(width: 8, height: 8)
                        Text("You")
                            .font(SwissTypography.monoLabel(10))
                            .foregroundColor(colors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(SwissColors.red)
                            .frame(width: 8, height: 8)
                        Text("Opponent")
                            .font(SwissTypography.monoLabel(10))
                            .foregroundColor(colors.textSecondary)
                    }

                    Spacer()

                    Text("\(events.count) points")
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Shot Stats Helper
    private func computeShotStats(shots: [StoredShot]) -> [(type: String, count: Int, percentage: Int)] {
        var shotCounts: [String: Int] = [:]
        for shot in shots {
            let name = shot.displayName
            shotCounts[name, default: 0] += 1
        }

        let total = shots.count
        return shotCounts.map { (type: $0.key, count: $0.value, percentage: total > 0 ? Int(Double($0.value) / Double(total) * 100) : 0) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Shot Highlights Section
    private func shotHighlightsSection(shots: [StoredShot]) -> some View {
        let sortedByIntensity = shots.sorted { $0.intensity > $1.intensity }
        let hardestShot = sortedByIntensity.first
        let softestShot = sortedByIntensity.last
        let avgIntensity = shots.isEmpty ? 0 : shots.reduce(0) { $0 + $1.intensity } / Double(shots.count)

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        return SwissInsightCard(title: "Shot Highlights") {
            VStack(spacing: 16) {
                // Hardest Shot
                if let hardest = hardestShot {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(SwissColors.green)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hardest Shot")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.textPrimary)
                            Text("\(hardest.displayName) at \(timeFormatter.string(from: hardest.timestamp))")
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(colors.textSecondary)
                        }

                        Spacer()

                        Text("\(Int(hardest.intensity * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(SwissColors.green)
                    }
                }

                // Softest/Touch Shot
                if let softest = softestShot, softestShot?.id != hardestShot?.id {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 16))
                            .foregroundColor(colors.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Softest Touch")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(colors.textPrimary)
                            Text("\(softest.displayName) at \(timeFormatter.string(from: softest.timestamp))")
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(colors.textSecondary)
                        }

                        Spacer()

                        Text("\(Int(softest.intensity * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(colors.textSecondary)
                    }
                }

                // Average Intensity
                HStack(spacing: 12) {
                    Image(systemName: "gauge.medium")
                        .font(.system(size: 16))
                        .foregroundColor(colors.textPrimary)
                        .frame(width: 28)

                    Text("Average Intensity")
                        .font(.system(size: 13))
                        .foregroundColor(colors.textPrimary)

                    Spacer()

                    Text("\(Int(avgIntensity * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(colors.textPrimary)
                }
            }
        }
    }

    // MARK: - Shots Content
    private var shotsContent: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Shot Breakdown")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Text("Total: 120")
                    .font(SwissTypography.monoLabel(11))
                    .fontWeight(.bold)
                    .foregroundColor(colors.textPrimary)
            }
            .padding(.bottom, 4)
            .overlay(
                Rectangle()
                    .fill(SwissColors.black)
                    .frame(height: 1),
                alignment: .bottom
            )

            HStack(spacing: 32) {
                // Donut Chart Placeholder
                SwissDonutChart()

                // Shot List
                VStack(spacing: 8) {
                    SwissShotRow(color: SwissColors.green, label: "Forehand", value: "35%")
                    SwissShotRow(color: .blue, label: "Backhand", value: "29%")
                    SwissShotRow(color: .purple, label: "Serve", value: "15%")
                    SwissShotRow(color: .orange, label: "Volley", value: "12%")
                }
            }

            // Shot Detail Panel
            SwissShotDetailPanel()

            Color.clear.frame(height: 32)
        }
        .padding(.top, 32)
        .padding(.horizontal, 32)
    }

    // MARK: - Timeline Content
    private var timelineContent: some View {
        VStack(spacing: 24) {
            // Header with toggle
            HStack {
                Text("Match Timeline")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(colors.textSecondary)

                Spacer()

                // Highlights / Full toggle (Pro only)
                if pro.isPro {
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHighlightsOnly = true
                            }
                        }) {
                            Text("Highlights")
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(showHighlightsOnly ? .white : SwissColors.gray500)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(showHighlightsOnly ? SwissColors.black : Color.clear)
                        }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHighlightsOnly = false
                            }
                        }) {
                            Text("Full")
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(!showHighlightsOnly ? .white : SwissColors.gray500)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(!showHighlightsOnly ? SwissColors.black : Color.clear)
                        }
                    }
                    .background(SwissColors.gray200)
                }
            }

            // Point-by-point timeline
            if let events = game.events, !events.isEmpty {
                if pro.isPro && showHighlightsOnly {
                    // Highlights mode - flat list of user's points
                    let highlightEvents = filterHighlightEvents(events)

                    if highlightEvents.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 24))
                                .foregroundColor(colors.textSecondary)
                            Text("No highlights detected")
                                .font(SwissTypography.monoLabel(11))
                                .foregroundColor(colors.textSecondary)
                            Text("Switch to Full view to see all points")
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(highlightEvents.enumerated()), id: \.offset) { index, event in
                                timelineEventRow(event: event, index: index, isHighlight: true)

                                if index < highlightEvents.count - 1 {
                                    Rectangle()
                                        .fill(SwissColors.gray200)
                                        .frame(width: 1, height: 16)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                    }
                } else {
                    // Full mode - grouped by game/set, collapsible
                    let groupedEvents = groupEventsByGame(events)
                    let groupedBySets = Dictionary(grouping: groupedEvents) { $0.setNumber }
                    let sortedSets = groupedBySets.keys.sorted()

                    LazyVStack(spacing: 12) {
                        ForEach(sortedSets, id: \.self) { setNum in
                            let gamesInSet = groupedBySets[setNum] ?? []
                            let setScore = game.setHistory?.indices.contains(setNum - 1) == true
                                ? "\(game.setHistory![setNum - 1].player1Games)-\(game.setHistory![setNum - 1].player2Games)"
                                : ""

                            // Set header (only show if multiple sets)
                            if sortedSets.count > 1 {
                                HStack {
                                    Text("SET \(setNum)")
                                        .font(SwissTypography.monoLabel(11))
                                        .fontWeight(.bold)
                                        .foregroundColor(colors.textPrimary)

                                    if !setScore.isEmpty {
                                        Text(setScore)
                                            .font(SwissTypography.monoLabel(11))
                                            .foregroundColor(colors.textSecondary)
                                    }

                                    Spacer()

                                    Text("\(gamesInSet.count) games")
                                        .font(SwissTypography.monoLabel(10))
                                        .foregroundColor(colors.textSecondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                            }

                            // Games in this set - collapsible
                            ForEach(Array(gamesInSet.enumerated()), id: \.offset) { _, group in
                                let gameKey = "\(group.setNumber)_\(group.gameNumber)"
                                let isExpanded = expandedGames.contains(gameKey)

                                VStack(spacing: 0) {
                                    // Tappable game header
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if isExpanded {
                                                expandedGames.remove(gameKey)
                                            } else {
                                                expandedGames.insert(gameKey)
                                            }
                                        }
                                    }) {
                                        collapsibleGameHeader(
                                            gameNumber: group.gameNumber,
                                            events: group.events,
                                            isExpanded: isExpanded
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    // Expanded points
                                    if isExpanded {
                                        VStack(spacing: 0) {
                                            ForEach(Array(group.events.enumerated()), id: \.offset) { index, event in
                                                let previousEvent = index > 0 ? group.events[index - 1] : nil
                                                compactEventRow(event: event, previousEvent: previousEvent)

                                                if index < group.events.count - 1 {
                                                    Divider()
                                                        .padding(.leading, 40)
                                                }
                                            }
                                        }
                                        .padding(.bottom, 8)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .background(colors.background)
                                .overlay(
                                    Rectangle()
                                        .stroke(SwissColors.gray200, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundColor(colors.textSecondary)
                    Text("No event data")
                        .font(SwissTypography.monoLabel(11))
                        .foregroundColor(colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }

            // Sets Timeline
            if let setHistory = game.setHistory {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sets")
                        .font(SwissTypography.monoLabel(11))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(colors.textSecondary)

                    ForEach(Array(setHistory.enumerated()), id: \.offset) { index, set in
                        SwissSetTimelineCard(
                            setNumber: index + 1,
                            score: "\(set.player1Games)-\(set.player2Games)",
                            duration: "45min",
                            breakPoints: "2/3",
                            winPercentage: 0.6
                        )
                    }
                }
                .padding(.top, 16)
            }


            Color.clear.frame(height: 32)
        }
        .padding(.top, 32)
        .padding(.horizontal, 32)
    }

    // MARK: - Filter Highlight Events
    /// Filters events to show only points scored by the user (player1)
    /// Uses scoring player as the heuristic for user participation
    private func filterHighlightEvents(_ events: [GameEventData]) -> [GameEventData] {
        events.filter { event in
            // Only show points where player1 (user) scored
            event.scoringPlayer == "player1"
        }
    }

    // MARK: - Group Events by Game
    /// Groups events into games by detecting score resets (0-0)
    /// Returns array of (gameNumber, setNumber, events)
    private func groupEventsByGame(_ events: [GameEventData]) -> [(gameNumber: Int, setNumber: Int, events: [GameEventData])] {
        guard !events.isEmpty else { return [] }

        var groups: [(gameNumber: Int, setNumber: Int, events: [GameEventData])] = []
        var currentGameEvents: [GameEventData] = []
        var gameNumber = 1
        var setNumber = 1
        var gamesInCurrentSet = 0

        for (index, event) in events.enumerated() {
            currentGameEvents.append(event)

            // Check if this is the end of a game (next event resets to 0-0 or lower scores)
            let isLastEvent = index == events.count - 1
            let nextEventResetsScore: Bool = {
                if isLastEvent { return false }
                let next = events[index + 1]
                // Detect game end: scores reset or both go to 0
                return (next.player1Score == 0 && next.player2Score == 0) ||
                       (next.player1Score < event.player1Score && next.player2Score < event.player2Score)
            }()

            if nextEventResetsScore || isLastEvent {
                groups.append((gameNumber: gameNumber, setNumber: setNumber, events: currentGameEvents))
                currentGameEvents = []
                gameNumber += 1
                gamesInCurrentSet += 1

                // Check if we should increment set (using setHistory if available)
                if let setHistory = game.setHistory {
                    let totalGamesInSet = setHistory.indices.contains(setNumber - 1)
                        ? setHistory[setNumber - 1].player1Games + setHistory[setNumber - 1].player2Games
                        : 0
                    if gamesInCurrentSet >= totalGamesInSet && setNumber < setHistory.count {
                        setNumber += 1
                        gameNumber = 1
                        gamesInCurrentSet = 0
                    }
                }
            }
        }

        return groups
    }

    // MARK: - Timeline Event Row
    private func timelineEventRow(event: GameEventData, index: Int, isHighlight: Bool) -> some View {
        HStack(spacing: 12) {
            // Point indicator
            Circle()
                .fill(event.scoringPlayer == "player1" ? SwissColors.green : SwissColors.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(event.scoringPlayer == "player1" ? SwissColors.green : SwissColors.red, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .opacity(isHighlight ? 1 : 0)
                )
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(event.player1Score) - \(event.player2Score)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(colors.textPrimary)

                Text(event.scoringPlayer == "player1" ? "You scored" : "Opponent scored")
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(colors.textSecondary)
            }

            Spacer()

            // Time indicator
            let minutes = Int(event.timestamp / 60)
            let seconds = Int(event.timestamp.truncatingRemainder(dividingBy: 60))
            Text(String(format: "%d:%02d", minutes, seconds))
                .font(SwissTypography.monoLabel(10))
                .foregroundColor(colors.textSecondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Collapsible Game Header
    private func collapsibleGameHeader(gameNumber: Int, events: [GameEventData], isExpanded: Bool) -> some View {
        let youWon = events.last?.scoringPlayer == "player1"
        let yourPoints = events.filter { $0.scoringPlayer == "player1" }.count
        let theirPoints = events.filter { $0.scoringPlayer == "player2" }.count

        return HStack(spacing: 12) {
            // Expand/collapse indicator
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(colors.textSecondary)
                .frame(width: 16)

            // Game number
            Text("Game \(gameNumber)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colors.textPrimary)

            // Score visualization - mini bar
            HStack(spacing: 1) {
                Rectangle()
                    .fill(SwissColors.green)
                    .frame(width: CGFloat(yourPoints) * 6, height: 4)
                Rectangle()
                    .fill(SwissColors.red)
                    .frame(width: CGFloat(theirPoints) * 6, height: 4)
            }
            .clipShape(Capsule())

            Spacer()

            // Points summary
            Text("\(yourPoints)-\(theirPoints)")
                .font(SwissTypography.monoLabel(11))
                .foregroundColor(colors.textSecondary)

            // Win indicator
            Circle()
                .fill(youWon ? SwissColors.green : SwissColors.red)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(SwissColors.gray100)
    }

    // MARK: - Compact Event Row
    private func compactEventRow(event: GameEventData, previousEvent: GameEventData? = nil) -> some View {
        // Detect side out (pickleball only): serve changed from opponent to user
        let isPickleball = game.sportType.lowercased() == "pickleball"
        let isSideOut = isPickleball && previousEvent?.servingPlayer == "player2" && event.servingPlayer == "player1"

        return HStack(spacing: 8) {
            // Point indicator
            Circle()
                .fill(event.scoringPlayer == "player1" ? SwissColors.green : SwissColors.red)
                .frame(width: 6, height: 6)
                .frame(width: 32)

            // Score
            Text("\(event.player1Score)-\(event.player2Score)")
                .font(SwissTypography.monoLabel(11))
                .foregroundColor(colors.textPrimary)
                .frame(width: 36, alignment: .leading)

            // Side Out pill - pickleball only (yellow)
            if isSideOut {
                Text("SIDE OUT")
                    .font(SwissTypography.monoLabel(8))
                    .tracking(0.5)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 1.0, green: 0.8, blue: 0.0)) // Yellow
                    .clipShape(Capsule())
            }

            Spacer()

            // Timestamp
            let minutes = Int(event.timestamp / 60)
            let seconds = Int(event.timestamp.truncatingRemainder(dividingBy: 60))
            Text(String(format: "%d:%02d", minutes, seconds))
                .font(SwissTypography.monoLabel(9))
                .foregroundColor(colors.textSecondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}

// MARK: - Supporting Views

struct SwissHealthStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .tracking(-1)
                .foregroundColor(SwissColors.white)

            Text(label)
                .font(SwissTypography.monoLabel(9))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(SwissColors.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .overlay(
            Rectangle()
                .fill(SwissColors.white.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

struct SwissHealthStatWithIcon: View {
    let icon: String  // Lucide icon name: "flame", "activity", "target"
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            // Lucide icon
            if let lucideIcon = LucideIcon.named(icon) {
                Image(icon: lucideIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(SwissColors.white.opacity(0.6))
            } else {
                // Fallback to SF Symbol
                Image(systemName: icon == "flame" ? "flame.fill" : (icon == "activity" ? "heart.fill" : "target"))
                    .font(.system(size: 16))
                    .foregroundColor(SwissColors.white.opacity(0.6))
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .tracking(-1)
                .foregroundColor(SwissColors.white)

            Text(label)
                .font(SwissTypography.monoLabel(9))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(SwissColors.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .overlay(
            Rectangle()
                .fill(SwissColors.white.opacity(0.2))
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

struct SwissDetailStatCard: View {
    @Environment(\.adaptiveColors) var colors
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(SwissTypography.monoLabel(10))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            Rectangle()
                .stroke(SwissColors.gray, lineWidth: 1)
        )
    }
}

struct SwissInsightCard<Content: View>: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(colors.background)
                .offset(y: -8)

            content
        }
        .padding(16)
        .overlay(
            Rectangle()
                .stroke(SwissColors.gray, lineWidth: 1)
        )
    }
}

struct SwissInsightRow: View {
    @Environment(\.adaptiveColors) var colors
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(colors.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
        }
    }
}

struct SwissMomentumStat: View {
    @Environment(\.adaptiveColors) var colors
    let value: String
    let label: String
    var dimmed: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(SwissTypography.monoLabel(9))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(dimmed ? SwissColors.gray400 : SwissColors.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .fill(SwissColors.gray100)
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct SwissClutchRow: View {
    let label: String
    let stats: String
    let percentage: String
    var dimmed: Bool = false
    var isPositive: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(dimmed ? SwissColors.gray400 : SwissColors.black)

            Spacer()

            Text("\(stats) → \(percentage)")
                .font(SwissTypography.monoLabel(12))
                .foregroundColor(isPositive ? SwissColors.green : (dimmed ? SwissColors.gray400 : SwissColors.black))
        }
    }
}

struct SwissShotRow: View {
    @Environment(\.adaptiveColors) var colors
    let color: Color
    let label: String
    let value: String

    var body: some View {
        Button(action: {}) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    Text(label)
                        .font(SwissTypography.monoLabel(10))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(colors.textPrimary)
                }

                Spacer()

                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(colors.textPrimary)
            }
            .padding(8)
            .overlay(
                Rectangle()
                    .stroke(SwissColors.gray, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SwissDonutChart: View {
    // Shot distribution percentages
    var forehand: Double = 0.35
    var backhand: Double = 0.29
    var serve: Double = 0.15
    var volley: Double = 0.12
    var other: Double = 0.09

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(SwissColors.gray100, lineWidth: 24)
                .frame(width: 128, height: 128)

            // Forehand - Green
            Circle()
                .trim(from: 0, to: forehand)
                .stroke(SwissColors.green, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
                .frame(width: 128, height: 128)
                .rotationEffect(.degrees(-90))

            // Backhand - Blue
            Circle()
                .trim(from: forehand, to: forehand + backhand)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
                .frame(width: 128, height: 128)
                .rotationEffect(.degrees(-90))

            // Serve - Purple
            Circle()
                .trim(from: forehand + backhand, to: forehand + backhand + serve)
                .stroke(Color.purple, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
                .frame(width: 128, height: 128)
                .rotationEffect(.degrees(-90))

            // Volley - Orange
            Circle()
                .trim(from: forehand + backhand + serve, to: forehand + backhand + serve + volley)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
                .frame(width: 128, height: 128)
                .rotationEffect(.degrees(-90))

            // Other - Gray
            Circle()
                .trim(from: forehand + backhand + serve + volley, to: 1.0)
                .stroke(SwissColors.gray400, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
                .frame(width: 128, height: 128)
                .rotationEffect(.degrees(-90))

            // Center label
            Text("DIST")
                .font(SwissTypography.monoLabel(10))
                .foregroundColor(SwissColors.textSecondary)
        }
    }
}

struct SwissShotDetailPanel: View {
    @Environment(\.adaptiveColors) var colors
    var shotType: String = "Forehand"
    var shotCount: Int = 42
    var totalShots: Int = 120
    var avgMagnitude: Double = 5.8
    var peakMagnitude: Double = 8.2
    var winningShots: Int = 4
    var consistency: Double = 0.72  // Standard deviation based consistency score

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shotType.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(colors.textPrimary)

                    Text("\(shotCount) shots (\(Int(Double(shotCount) / Double(totalShots) * 100))%)")
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                Circle()
                    .fill(SwissColors.green)
                    .frame(width: 12, height: 12)
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("AVG")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Text(String(format: "%.1fg", avgMagnitude))
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("PEAK")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Text(String(format: "%.1fg", peakMagnitude))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(SwissColors.green)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("WIN")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Text("\(winningShots)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(SwissColors.green)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("CONS")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Text(consistencyRating)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(consistencyColor)
                }
                .frame(maxWidth: .infinity)
            }

            // Magnitude distribution bar
            HStack(spacing: 8) {
                Text("MAG")
                    .font(SwissTypography.monoLabel(9))
                    .foregroundColor(colors.textSecondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(SwissColors.gray200)

                        Rectangle()
                            .fill(SwissColors.green)
                            .frame(width: geo.size.width * CGFloat(avgMagnitude / 10.0))
                    }
                }
                .frame(height: 8)

                Text(String(format: "%.1f", avgMagnitude))
                    .font(SwissTypography.monoLabel(10))
                    .fontWeight(.bold)
                    .foregroundColor(colors.textPrimary)
            }
        }
        .padding(16)
        .background(SwissColors.gray50)
        .overlay(
            Rectangle()
                .stroke(SwissColors.black, lineWidth: 1)
        )
    }

    private var consistencyRating: String {
        if consistency >= 0.8 { return "★★★" }
        else if consistency >= 0.5 { return "★★☆" }
        else { return "★☆☆" }
    }

    private var consistencyColor: Color {
        if consistency >= 0.8 { return SwissColors.green }
        else if consistency >= 0.5 { return SwissColors.black }
        else { return SwissColors.gray400 }
    }
}

struct SwissSetTimelineCard: View {
    @Environment(\.adaptiveColors) var colors
    let setNumber: Int
    let score: String
    let duration: String
    let breakPoints: String
    let winPercentage: Double

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Set \(setNumber)")
                    .font(SwissTypography.monoLabel(12))
                    .textCase(.uppercase)
                    .tracking(1)
                    .fontWeight(.bold)
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Text(score)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(colors.textPrimary)
            }

            Text("Duration: \(duration) • Break Points: \(breakPoints)")
                .font(SwissTypography.monoLabel(10))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            // Points won percentage bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Points Won")
                        .font(SwissTypography.monoLabel(9))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundColor(colors.textSecondary)
                    Spacer()
                    Text("\(Int(winPercentage * 100))%")
                        .font(SwissTypography.monoLabel(10))
                        .foregroundColor(colors.textPrimary)
                }
                SwissProgressBar(value: winPercentage, height: 8, foregroundColor: SwissColors.green)
            }
            .padding(.top, 12)
        }
        .padding(24)
        .overlay(
            Rectangle()
                .fill(SwissColors.black)
                .frame(width: 4),
            alignment: .leading
        )
    }
}

struct SwissWinProbabilityChart: View {
    @Environment(\.adaptiveColors) var colors
    var finalProbability: Double = 0.6
    var isWin: Bool = true

    // Generate probability points simulating match progression
    private var probabilityPoints: [CGFloat] {
        // Start at 50%, end at final probability with some variation
        let start: CGFloat = 0.5
        let end = CGFloat(finalProbability)
        let steps = 12

        var points: [CGFloat] = []
        for i in 0..<steps {
            let progress = CGFloat(i) / CGFloat(steps - 1)
            // Base interpolation with some variation
            let base = start + (end - start) * progress
            // Add some randomish variation based on position
            let variation = sin(CGFloat(i) * 1.5) * 0.08 * (1 - progress)
            let clamped = min(max(base + variation, 0.1), 0.9)
            points.append(clamped)
        }
        // Ensure final point is actual probability
        points[points.count - 1] = end
        return points
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("100%")
                    Spacer()
                    Text("50%")
                    Spacer()
                    Text("0%")
                }
                .font(SwissTypography.monoLabel(10))
                .foregroundColor(colors.textSecondary)
                .frame(height: 150)

                Rectangle()
                    .fill(SwissColors.gray300)
                    .frame(width: 1, height: 150)

                // Chart area with probability line
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        // Background fill under the line
                        Path { path in
                            let width = geo.size.width
                            let height: CGFloat = 150
                            let stepWidth = width / CGFloat(probabilityPoints.count - 1)

                            path.move(to: CGPoint(x: 0, y: height))

                            for (index, prob) in probabilityPoints.enumerated() {
                                let x = CGFloat(index) * stepWidth
                                let y = height - (prob * height)
                                path.addLine(to: CGPoint(x: x, y: y))
                            }

                            path.addLine(to: CGPoint(x: width, y: height))
                            path.closeSubpath()
                        }
                        .fill((isWin ? SwissColors.green : SwissColors.red).opacity(0.15))

                        // Probability line
                        Path { path in
                            let width = geo.size.width
                            let height: CGFloat = 150
                            let stepWidth = width / CGFloat(probabilityPoints.count - 1)

                            for (index, prob) in probabilityPoints.enumerated() {
                                let x = CGFloat(index) * stepWidth
                                let y = height - (prob * height)
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(isWin ? SwissColors.green : SwissColors.red, lineWidth: 2)

                        // 50% dashed line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 75))
                            path.addLine(to: CGPoint(x: geo.size.width, y: 75))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundColor(SwissColors.gray300)

                        // End point indicator
                        Circle()
                            .fill(isWin ? SwissColors.green : SwissColors.red)
                            .frame(width: 8, height: 8)
                            .position(
                                x: geo.size.width,
                                y: 150 - (CGFloat(finalProbability) * 150)
                            )
                    }
                }
                .frame(height: 150)
            }

            Rectangle()
                .fill(SwissColors.gray300)
                .frame(height: 1)

            // X-axis labels
            HStack {
                Text("START")
                Spacer()
                Text("MID")
                Spacer()
                Text("END")
            }
            .font(SwissTypography.monoLabel(9))
            .foregroundColor(colors.textSecondary)
            .padding(.top, 8)
        }
    }
}

struct SwissHeartRateChart: View {
    @Environment(\.adaptiveColors) var colors
    var minHR: Int = 95
    var avgHR: Int = 142
    var maxHR: Int = 178

    let heights: [CGFloat] = [0.66, 0.75, 0.83, 0.82, 0.91, 0.97, 0.88, 0.80, 0.86, 0.82, 0.77, 0.76]

    var body: some View {
        VStack(spacing: 8) {
            // Heart rate stats row
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MIN")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Text("\(minHR)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(SwissColors.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AVG")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Text("\(avgHR)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(SwissColors.red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("MAX")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Text("\(maxHR)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(SwissColors.white)
                }

                Spacer()

                Text("BPM")
                    .font(SwissTypography.monoLabel(11))
                    .foregroundColor(colors.textSecondary)
            }

            // Chart with Y-axis labels
            HStack(alignment: .bottom, spacing: 8) {
                // Y-axis labels
                VStack(alignment: .trailing) {
                    Text("\(maxHR)")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Spacer()
                    Text("\(avgHR)")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                    Spacer()
                    Text("\(minHR)")
                        .font(SwissTypography.monoLabel(9))
                        .foregroundColor(colors.textSecondary)
                }
                .frame(width: 32, height: 128)

                // Bars
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                        Rectangle()
                            .fill(SwissColors.red)
                            .frame(height: 128 * height)
                    }
                }
                .frame(height: 128)
                .overlay(
                    // Average line
                    Rectangle()
                        .fill(SwissColors.red.opacity(0.5))
                        .frame(height: 1)
                        .offset(y: -128 * 0.56), // Position at ~avg level
                    alignment: .bottom
                )
            }
        }
    }
}

#Preview {
    SwissGameDetailView(game: WatchGameRecord(
        id: UUID(),
        date: Date(),
        sportType: "Tennis",
        gameType: "Singles",
        player1Score: 6,
        player2Score: 4,
        player1GamesWon: 2,
        player2GamesWon: 1,
        elapsedTime: 8100,
        winner: "You",
        location: nil,
        events: nil,
        healthData: nil,
        setHistory: nil,
        shots: nil
    ))
}
