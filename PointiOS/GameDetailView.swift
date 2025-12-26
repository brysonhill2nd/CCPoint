//
//  GameDetailView.swift
//  PointiOS
//
//  Clean, Modern Game Detail View for iOS
//

import SwiftUI

// MARK: - Legacy Game Event (local to this file)
fileprivate struct LegacyGameEvent {
    let timestamp: TimeInterval
    let player1Score: Int
    let player2Score: Int
    let scoringPlayer: LegacyPlayer
    let isServePoint: Bool
    let shotType: ShotType?
}

fileprivate enum LegacyPlayer {
    case player1, player2
}

// MARK: - Legacy Game Insights (local to this file)
fileprivate struct LegacyGameInsights {
    let events: [LegacyGameEvent]
    let finalScore: (player1: Int, player2: Int)
    let winner: LegacyPlayer
    let duration: TimeInterval

    var maxLead: Int {
        events.map { abs($0.player1Score - $0.player2Score) }.max() ?? 0
    }

    var leadChanges: Int {
        var changes = 0
        var lastLeader: LegacyPlayer? = nil

        for event in events {
            let currentLeader: LegacyPlayer? = {
                if event.player1Score > event.player2Score { return .player1 }
                else if event.player2Score > event.player1Score { return .player2 }
                else { return nil }
            }()

            if let current = currentLeader, current != lastLeader {
                if lastLeader != nil { changes += 1 }
                lastLeader = current
            }
        }
        return changes
    }

    var longestRun: (player: LegacyPlayer, points: Int) {
        var currentRun = 0
        var currentPlayer: LegacyPlayer? = nil
        var maxRun = 0
        var maxRunPlayer: LegacyPlayer = .player1

        for event in events {
            let scorer = event.scoringPlayer
            if scorer == currentPlayer {
                currentRun += 1
            } else {
                currentPlayer = scorer
                currentRun = 1
            }
            if currentRun > maxRun {
                maxRun = currentRun
                maxRunPlayer = scorer
            }
        }
        return (maxRunPlayer, maxRun)
    }

    var percentageInLead: Int {
        guard !events.isEmpty else { return 0 }
        let inLead = events.filter { $0.player1Score > $0.player2Score }.count
        return Int(Double(inLead) / Double(events.count) * 100)
    }
}

struct GameDetailView: View {
    let game: WatchGameRecord
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: DetailTab = .overview
    @State private var showingPointByPoint = false
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingUpgrade = false
    @State private var aiInsight: GameInsightLLMResult?
    @State private var aiInsightError: String?
    @State private var aiInsightLoading = false
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case insights = "Insights"
        case pointByPoint = "Points"
    }
    
    // Legacy insights for stats grid
    private var insights: LegacyGameInsights? {
        guard let events = game.events, !events.isEmpty else { return nil }

        let gameEvents = events.map { event in
            LegacyGameEvent(
                timestamp: event.timestamp,
                player1Score: event.player1Score,
                player2Score: event.player2Score,
                scoringPlayer: event.scoringPlayer == "player1" ? .player1 : .player2,
                isServePoint: event.isServePoint,
                shotType: ShotType(rawValue: event.shotType ?? "")
            )
        }

        return LegacyGameInsights(
            events: gameEvents,
            finalScore: (player1: game.player1Score, player2: game.player2Score),
            winner: game.winner == "You" ? .player1 : .player2,
            duration: game.elapsedTime
        )
    }
    
    // New heuristic insights
    private var heuristicPayload: GameInsightPayload? {
        GameInsightGenerator.generate(for: game)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Tab Selector
                    TabSelector(selectedTab: $selectedTab)
                        .padding(.horizontal, 20)
                    
                    // Content based on selected tab
                    switch selectedTab {
                    case .overview:
                        OverviewContent(
                            game: game,
                            insights: insights,
                            heuristicPayload: heuristicPayload,
                            aiInsight: aiInsight,
                            aiError: aiInsightError,
                            aiLoading: aiInsightLoading,
                            isPro: pro.isPro,
                            upgrade: { showingUpgrade = true }
                        )
                    case .insights:
                        ServeInsightsContent(game: game, isPro: pro.isPro, upgrade: { showingUpgrade = true })
                    case .pointByPoint:
                        PointsContent(game: game)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.top, 20)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topTrailing) {
            // Done button - Liquid Glass Style
            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            // Glassmorphism effect
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )

                            // Border glow
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            .padding()
        }
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
        }
        .task {
            await loadAIInsight()
        }
    }
}

// MARK: - Tab Selector
struct TabSelector: View {
    @Binding var selectedTab: GameDetailView.DetailTab
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(GameDetailView.DetailTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .white : Color(.sRGB, white: 0.63, opacity: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                        )
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Overview Content
fileprivate struct OverviewContent: View {
    let game: WatchGameRecord
    let insights: LegacyGameInsights?
    let heuristicPayload: GameInsightPayload?
    let aiInsight: GameInsightLLMResult?
    let aiError: String?
    let aiLoading: Bool
    let isPro: Bool
    let upgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Score Card
            ScoreCard(game: game)
            
            // Stats Grid - Moved from separate Stats tab
            if let insights = insights {
                if isPro {
                    StatsGrid(insights: insights)
                } else {
                    LockedFeatureCard(
                        title: "Advanced Stats",
                        description: "Unlock Point Pro to view lead changes, streaks, and advanced charts."
                    ) {
                        upgrade()
                    }
                }
            }
            
            if let payload = aiInsight?.payload ?? heuristicPayload {
                if isPro {
                    DetailedInsightSection(
                        payload: payload,
                        sportType: game.sportType,
                        loading: aiLoading,
                        error: aiError
                    )
                } else {
                    LockedFeatureCard(
                        title: "Premium Insights",
                        description: "AI-powered recommendations and deep breakdowns require Point Pro."
                    ) {
                        upgrade()
                    }
                }
            }

            // Shot Analytics Section
            if game.shots != nil && !(game.shots?.isEmpty ?? true) {
                if isPro {
                    ShotDistributionCard(game: game)
                } else {
                    LockedShotAnalyticsCard {
                        upgrade()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Score Card
struct ScoreCard: View {
    let game: WatchGameRecord
    
    var body: some View {
        VStack(spacing: 8) {
            // Sport Header
            HStack(spacing: 6) {
                Text(game.sportEmoji)
                    .font(.system(size: 22))
                
                Text("\(game.sportType) \(game.gameType)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.top, 2)
            
            // Main Score Display
            if game.sportType == "Tennis" || game.sportType == "Padel" {
                TennisScoreView(game: game)
            } else {
                PickleballScoreView(game: game)
            }
            
            // Result Badge
            Text(game.winner == "You" ? "Victory" : "Defeat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(game.winner == "You" ? .green : .red)
                .padding(.vertical, 2)
            
            // Meta Info - condensed single line with health
            HStack(spacing: 4) {
                Text(game.date.formatted(.dateTime.month(.abbreviated).day()))
                    .foregroundColor(.gray)
                    .font(.system(size: 11))
                dot
                Text("Games \(game.player1GamesWon)-\(game.player2GamesWon)")
                    .foregroundColor(.gray)
                    .font(.system(size: 11))
                dot
                Text(game.elapsedTimeDisplay)
                    .foregroundColor(.gray)
                    .font(.system(size: 11))
                if let health = game.healthData {
                    dot
                    Text("\(Int(health.totalCalories)) cal")
                        .foregroundColor(.gray)
                        .font(.system(size: 11))
                    dot
                    Text("\(Int(health.averageHeartRate)) bpm")
                        .foregroundColor(.gray)
                        .font(.system(size: 11))
                }
            }
            .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
    
    private var dot: some View {
        Text("•")
            .foregroundColor(.gray)
            .font(.system(size: 10))
    }
}

// MARK: - Tennis Score View
struct TennisScoreView: View {
    let game: WatchGameRecord
    
    var body: some View {
        VStack(spacing: 20) {
            // Sets Display
            if let setHistory = game.setHistory {
                VStack(spacing: 12) {
                    ForEach(Array(setHistory.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Text("\(set.player1Games)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(set.player1Games > set.player2Games ? .green : .white)
                                Text("-")
                                    .foregroundColor(.gray)
                                Text("\(set.player2Games)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(set.player2Games > set.player1Games ? .red : .white)
                                
                                if let tb = set.tiebreakScore {
                                    Text("(\(tb.0)-\(tb.1))")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 8)
                    
                    // Match Score
                    HStack {
                        Text("Match")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Text("\(game.player1GamesWon)")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(game.winner == "You" ? .green : .white)
                            Text("-")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            Text("\(game.player2GamesWon)")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(game.winner == "Opponent" ? .red : .white)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pickleball Score View
struct PickleballScoreView: View {
    let game: WatchGameRecord
    
    var body: some View {
        VStack(spacing: 20) {
            if game.player1GamesWon > 0 || game.player2GamesWon > 0 {
                // Multi-game match
                if let gameHistory = game.setHistory {
                    VStack(spacing: 12) {
                        ForEach(Array(gameHistory.enumerated()), id: \.offset) { index, gameScore in
                            HStack {
                                Text("Game \(index + 1)")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Text("\(gameScore.player1Games)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(gameScore.player1Games > gameScore.player2Games ? .green : .white)
                                    Text("-")
                                        .foregroundColor(.gray)
                                    Text("\(gameScore.player2Games)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(gameScore.player2Games > gameScore.player1Games ? .red : .white)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 8)
                        
                        // Match Score
                        HStack {
                            Text("Match")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Text("\(game.player1GamesWon)")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundColor(game.winner == "You" ? .green : .white)
                                Text("-")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("\(game.player2GamesWon)")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundColor(game.winner == "Opponent" ? .red : .white)
                            }
                        }
                    }
                } else {
                    // Simple games display
                    Text("Games: \(game.player1GamesWon) - \(game.player2GamesWon)")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            
            // Main Score (always show for Pickleball)
            HStack(spacing: 24) {
                Text("\(game.player1Score)")
                    .font(.system(size: 84, weight: .bold))
                    .foregroundColor(game.winner == "You" ? .green : .white)
                
                Text("-")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("\(game.player2Score)")
                    .font(.system(size: 84, weight: .bold))
                    .foregroundColor(game.winner == "Opponent" ? .red : .white)
            }
        }
    }
}







// MARK: - Stats Grid
fileprivate struct StatsGrid: View {
    let insights: LegacyGameInsights
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCardLarge(
                    icon: "↗️",
                    iconColor: .blue,
                    value: "\(insights.maxLead)",
                    title: "Max Lead"
                )
                
                StatCardLarge(
                    icon: "↔️",
                    iconColor: .orange,
                    value: "\(insights.leadChanges)",
                    title: "Lead Changes"
                )
            }
            
            HStack(spacing: 16) {
                StatCardLarge(
                    icon: "🔥",
                    iconColor: .red,
                    value: "\(insights.longestRun.points)",
                    title: "Longest Run"
                )
                
                StatCardLarge(
                    icon: "📈",
                    iconColor: .green,
                    value: "\(insights.percentageInLead)%",
                    title: "Time in Lead"
                )
            }
        }
    }
}

struct DetailedInsightSection: View {
    let payload: GameInsightPayload
    let sportType: String
    let loading: Bool
    let error: String?
    
    private var servingPercent: Int {
        Int((payload.metrics.servingEfficiency * 100).rounded())
    }
    
    private var sideOutPercent: Int {
        Int((payload.metrics.sideOutRate * 100).rounded())
    }
    
    private var returnPercent: Int {
        guard payload.metrics.totalReturnPoints > 0 else { return 0 }
        return Int((Double(payload.metrics.pointsWonOnReturn) / Double(payload.metrics.totalReturnPoints) * 100).rounded())
    }
    
    private var pointWinPercent: Int {
        Int((payload.metrics.pointWinRate * 100).rounded())
    }
    
    private var toneColor: Color {
        switch payload.insights.tone {
        case .dominant:
            return .green
        case .clutch:
            return .blue
        case .competitive:
            return .yellow
        case .rough:
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Insights")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Pro")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(999)
            }
            
            if loading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
            
            Text(payload.insights.summary)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.85))
            
            VStack(spacing: 12) {
                InsightProgressRow(title: "Serving Efficiency", percent: servingPercent, color: .blue)
                if sportType.lowercased() == "padel" || sportType.lowercased() == "tennis" {
                    InsightProgressRow(title: "Return Point Win Rate",
                                       percent: returnPercent,
                                       color: .purple)
                } else {
                    InsightProgressRow(title: "Side-Out Rate", percent: sideOutPercent, color: .purple)
                }
                InsightProgressRow(title: "Point Win Rate", percent: pointWinPercent, color: .green)
            }
            
            if !payload.insights.strengths.isEmpty {
                InsightListSection(
                    title: "Strengths",
                    color: .green,
                    items: Array(payload.insights.strengths.prefix(3))
                )
            }
            
            if !payload.insights.weaknesses.isEmpty {
                InsightListSection(
                    title: "Opportunities",
                    color: .orange,
                    items: Array(payload.insights.weaknesses.prefix(3))
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(toneColor)
                Text(payload.insights.recommendation)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }
            
            if let error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .cornerRadius(24)
    }
}

struct InsightProgressRow: View {
    let title: String
    let percent: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }
            
            ProgressView(value: Double(percent), total: 100)
                .tint(color)
                .progressViewStyle(.linear)
        }
    }
}

struct InsightListSection: View {
    let title: String
    let color: Color
    let items: [InsightDetail]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            ForEach(Array(items.enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 8) {
                    Text(insight.icon)
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(insight.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(insight.data)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Text(insight.description)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(14)
            }
        }
    }
}

// MARK: - Stat Card Compact
struct StatCardCompact: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 24))
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Stat Card Large
struct StatCardLarge: View {
    let icon: String
    let iconColor: Color
    let value: String
    let title: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 32))
            
            Text(value)
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Points Content
struct PointsContent: View {
    let game: WatchGameRecord
    
    var body: some View {
        PointByPointBreakdown(game: game)
            .padding(.horizontal, 16)
    }
}

// MARK: - Point-by-Point Breakdown
struct PointByPointBreakdown: View {
    let game: WatchGameRecord
    @State private var expandedGroups: Set<Int> = []
    
    private var groups: [PointBreakdownGroup] {
        PointBreakdownBuilder.groups(for: game)
    }
    
    private var background: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.sRGB, white: 0.11, opacity: 0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.sRGB, white: 0.15, opacity: 1.0), lineWidth: 1)
            )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Point-by-Point Breakdown")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                if game.winner == nil {
                    Text("Match in progress")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.98, green: 0.80, blue: 0.25, opacity: 1.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.95, green: 0.75, blue: 0.19, opacity: 0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.95, green: 0.75, blue: 0.19, opacity: 0.3), lineWidth: 1)
                                )
                        )
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if groups.isEmpty {
                EmptyPointState()
            } else {
                VStack(spacing: 8) {
                    ForEach(groups) { group in
                        PointGroupCard(
                            group: group,
                            isExpanded: expandedGroups.contains(group.number),
                            onToggle: {
                                if expandedGroups.contains(group.number) {
                                    expandedGroups.remove(group.number)
                                } else {
                                    expandedGroups.insert(group.number)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(background)
        .cornerRadius(16)
    }
}

// MARK: - Point Group Card
struct PointGroupCard: View {
    let group: PointBreakdownGroup
    let isExpanded: Bool
    let onToggle: () -> Void
    
    private var badgeColors: (bg: Color, border: Color, text: Color) {
        switch group.result {
        case .win:
            return (
                Color(red: 0.25, green: 0.80, blue: 0.55, opacity: 0.1),
                Color(red: 0.25, green: 0.80, blue: 0.55, opacity: 0.3),
                Color(red: 0.34, green: 0.85, blue: 0.62, opacity: 1.0)
            )
        case .loss:
            return (
                Color(red: 0.94, green: 0.27, blue: 0.27, opacity: 0.1),
                Color(red: 0.94, green: 0.27, blue: 0.27, opacity: 0.3),
                Color(red: 0.98, green: 0.38, blue: 0.38, opacity: 1.0)
            )
        }
    }
    
    private var scoreColors: (you: Color, opponent: Color) {
        switch group.result {
        case .win:
            return (
                Color(red: 0.34, green: 0.85, blue: 0.62, opacity: 1.0),
                .white
            )
        case .loss:
            return (
                .white,
                Color(red: 0.98, green: 0.38, blue: 0.38, opacity: 1.0)
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(badgeColors.bg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(badgeColors.border, lineWidth: 1)
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("\(group.number)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(badgeColors.text)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Text("\(group.points.count) points")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.sRGB, white: 0.47, opacity: 1.0))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("\(group.playerScore)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(scoreColors.you)
                        Text("-")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(.sRGB, white: 0.38, opacity: 1.0))
                        Text("\(group.opponentScore)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(scoreColors.opponent)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(.sRGB, white: 0.63, opacity: 1.0))
                }
                .padding(12)
                .background(Color(.sRGB, white: 0.11, opacity: 0.5))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                    .background(Color(.sRGB, white: 0.15, opacity: 0.5))
                
                if group.points.isEmpty {
                    EmptyPointState()
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(group.points.enumerated()), id: \.offset) { index, point in
                            BreakdownPointRow(
                                point: point,
                                isFirst: index == 0,
                                isLast: index == group.points.count - 1
                            )
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.sRGB, white: 0.11, opacity: 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.sRGB, white: 0.15, opacity: 1.0), lineWidth: 1)
                )
        )
    }
}

// MARK: - Point Row Grid
struct BreakdownPointRow: View {
    let point: PointBreakdownPoint
    let isFirst: Bool
    let isLast: Bool
    
    private var scoreColor: Color {
        switch point.winner {
        case .you:
            return Color(red: 0.34, green: 0.85, blue: 0.62, opacity: 1.0)
        case .opponent:
            return Color(red: 0.98, green: 0.38, blue: 0.38, opacity: 1.0)
        case .none:
            return .white
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Point \(point.number)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.sRGB, white: 0.47, opacity: 1.0))
                Text(point.score)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(scoreColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if point.event == "Side Out" {
                Text("Side Out")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.98, green: 0.80, blue: 0.25, opacity: 1.0))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.95, green: 0.75, blue: 0.19, opacity: 0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color(red: 0.95, green: 0.75, blue: 0.19, opacity: 0.3), lineWidth: 1)
                            )
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }
            
            ServerDots(server: point.server)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.clear)
        .overlay(alignment: .top) {
            if isFirst {
                Divider()
                    .background(Color(.sRGB, white: 0.15, opacity: 1.0))
            }
        }
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .background(Color(.sRGB, white: 0.15, opacity: 0.5))
            }
        }
    }
}

// MARK: - Server Dots
struct ServerDots: View {
    let server: String
    
    private var dotInfo: (team: ServerTeam, count: Int) {
        let lower = server.lowercased()
        let team: ServerTeam = lower.contains("opponent") ? .opponent : .you
        let count = lower.contains("s2") ? 2 : 1
        return (team, count)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotInfo.count, id: \.self) { _ in
                Circle()
                    .fill(dotInfo.team == .you
                          ? Color(red: 0.25, green: 0.80, blue: 0.55, opacity: 1.0)
                          : Color(red: 0.94, green: 0.27, blue: 0.27, opacity: 1.0))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Empty State
struct EmptyPointState: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("No point data recorded")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text("Track a game on Apple Watch to see rally-by-rally details.")
                .font(.system(size: 13))
                .foregroundColor(Color(.sRGB, white: 0.63, opacity: 1.0))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }
}

// MARK: - Breakdown Models & Builder
private enum ServerTeam {
    case you
    case opponent
    
    var opposite: ServerTeam {
        self == .you ? .opponent : .you
    }
}

private enum ServerSlot {
    case s1
    case s2
    
    var next: ServerSlot {
        self == .s1 ? .s2 : .s1
    }
}

struct PointBreakdownGroup: Identifiable {
    enum Result {
        case win
        case loss
    }
    
    let id = UUID()
    let number: Int
    let title: String
    let playerScore: Int
    let opponentScore: Int
    let result: Result
    let points: [PointBreakdownPoint]
}

struct PointBreakdownPoint: Identifiable {
    enum Winner {
        case you
        case opponent
        case none
    }
    
    let id = UUID()
    let number: Int
    let score: String
    let winner: Winner
    let server: String
    let event: String?
}

enum PointBreakdownBuilder {
    static func groups(for game: WatchGameRecord) -> [PointBreakdownGroup] {
        let events = game.events ?? []
        if let sets = game.setHistory, !sets.isEmpty {
            let titlePrefix = game.sportType == "Tennis" ? "Set" : "Game"
            let eventBuckets = distribute(events: events, across: sets.count)
            
            return sets.enumerated().map { index, set in
                let points = buildPoints(from: eventBuckets[safe: index] ?? [])
                let youScore = set.player1Games
                let oppScore = set.player2Games
                return PointBreakdownGroup(
                    number: index + 1,
                    title: "\(titlePrefix) \(index + 1)",
                    playerScore: youScore,
                    opponentScore: oppScore,
                    result: youScore >= oppScore ? .win : .loss,
                    points: points
                )
            }
        } else {
            let points = buildPoints(from: events)
            return [
                PointBreakdownGroup(
                    number: 1,
                    title: "Game 1",
                    playerScore: game.player1Score,
                    opponentScore: game.player2Score,
                    result: game.player1Score >= game.player2Score ? .win : .loss,
                    points: points
                )
            ]
        }
    }
    
    private static func distribute(events: [GameEventData], across buckets: Int) -> [[GameEventData]] {
        guard buckets > 0 else { return [] }
        guard !events.isEmpty else { return Array(repeating: [], count: buckets) }
        
        let chunkSize = max(1, events.count / buckets)
        var grouped: [[GameEventData]] = Array(repeating: [], count: buckets)
        
        for (idx, event) in events.enumerated() {
            let bucketIndex = min(idx / chunkSize, buckets - 1)
            grouped[bucketIndex].append(event)
        }
        
        return grouped
    }
    
    private static func buildPoints(from events: [GameEventData]) -> [PointBreakdownPoint] {
        guard !events.isEmpty else { return [] }
        
        var points: [PointBreakdownPoint] = []
        var previousScore: (Int, Int) = (0, 0)
        var previousServerTeam: ServerTeam? = nil
        var serverTeam: ServerTeam = initialServer(from: events.first)
        var serverSlot: ServerSlot = .s1
        
        for (index, event) in events.enumerated() {
            let priorEvent = index > 0 ? events[index - 1] : nil
            let winner = winnerForEvent(event, previous: priorEvent, fallbackScore: previousScore)
            let sideOut = previousServerTeam == .opponent && serverTeam == .you
            
            let point = PointBreakdownPoint(
                number: index + 1,
                score: "\(event.player1Score)-\(event.player2Score)",
                winner: winner,
                server: format(serverTeam: serverTeam, slot: serverSlot),
                event: sideOut ? "Side Out" : nil
            )
            points.append(point)
            
            previousServerTeam = serverTeam
            previousScore = (event.player1Score, event.player2Score)
            
            switch winner {
            case .you:
                if serverTeam == .you {
                    serverSlot = serverSlot.next
                } else {
                    serverTeam = .you
                    serverSlot = .s1
                }
            case .opponent:
                if serverTeam == .opponent {
                    serverSlot = serverSlot.next
                } else {
                    serverTeam = .opponent
                    serverSlot = .s1
                }
            case .none:
                serverSlot = serverSlot.next
            }
        }
        
        return points
    }
    
    private static func initialServer(from event: GameEventData?) -> ServerTeam {
        guard let first = event else { return .you }
        let winner = winnerForEvent(first, previous: nil, fallbackScore: (0, 0))
        if first.isServePoint {
            return winner == .opponent ? .opponent : .you
        }
        return winner == .you ? .opponent : .you
    }
    
    private static func winnerForEvent(_ event: GameEventData, previous: GameEventData?, fallbackScore: (Int, Int)) -> PointBreakdownPoint.Winner {
        let prior = previous.map { ($0.player1Score, $0.player2Score) } ?? fallbackScore
        
        if event.player1Score > prior.0 {
            return .you
        } else if event.player2Score > prior.1 {
            return .opponent
        }
        
        let scorer = event.scoringPlayer.lowercased()
        if scorer.contains("you") || scorer.contains("player1") {
            return .you
        } else if scorer.contains("opponent") || scorer.contains("player2") {
            return .opponent
        }
        
        return .none
    }
    
    private static func format(serverTeam: ServerTeam, slot: ServerSlot) -> String {
        "\(serverTeam == .you ? "You" : "Opponent") \(slot == .s1 ? "S1" : "S2")"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

// MARK: - AI Insight Loader
extension GameDetailView {
    private func loadAIInsight() async {
        aiInsightLoading = true
        aiInsightError = nil

        guard let _ = heuristicPayload else {
            aiInsightLoading = false
            return
        }

        let result = await GPT4oMiniGameInsightService.generate(for: game)
        await MainActor.run {
            aiInsight = result
            aiInsightError = result?.error
            aiInsightLoading = false
        }
    }
}

// MARK: - Serve Insights Content
struct ServeInsightsContent: View {
    let game: WatchGameRecord
    let isPro: Bool
    let upgrade: () -> Void

    private var insights: GameInsightsResult? {
        GameInsightsCalculator.calculate(from: game)
    }

    var body: some View {
        VStack(spacing: 20) {
            if let insights = insights {
                if isPro {
                    // Serve Performance Section
                    ServePerformanceCard(insights: insights)

                    // Momentum Section
                    MomentumCard(insights: insights)

                    // Clutch Section
                    ClutchCard(insights: insights)
                } else {
                    LockedFeatureCard(
                        title: "Serve & Performance Insights",
                        description: "Unlock Point Pro to see serve hold rates, momentum analysis, and clutch performance."
                    ) {
                        upgrade()
                    }
                }
            } else {
                NoDataCard()
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Serve Performance Card
struct ServePerformanceCard: View {
    let insights: GameInsightsResult

    private var serve: ServeInsights { insights.serveInsights }
    private var isPickleball: Bool { insights.sportType == "Pickleball" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Serve Performance")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            // Your Serve
            if serve.youServedPoints > 0 {
                ServeStatRow(
                    label: "Your Serve",
                    points: serve.youServedPoints,
                    won: serve.youServedPointsWon,
                    rate: serve.yourServeWinRate,
                    color: .green
                )
            }

            // Partner Serve (doubles only)
            if insights.isDoubles && serve.partnerServedPoints > 0 {
                ServeStatRow(
                    label: "Partner's Serve",
                    points: serve.partnerServedPoints,
                    won: serve.partnerServedPointsWon,
                    rate: serve.partnerServeWinRate,
                    color: .orange
                )
            }

            // Return Performance
            if serve.opponentServedPoints > 0 {
                Divider()
                    .background(Color.white.opacity(0.1))

                if isPickleball {
                    ServeStatRow(
                        label: "Return Defense",
                        points: serve.opponentServedPoints,
                        won: serve.opponentServedPointsDefended,
                        rate: serve.returnDefenseRate,
                        color: .purple,
                        subtitle: "Side-outs forced"
                    )
                } else {
                    ServeStatRow(
                        label: "Break Points Won",
                        points: serve.opponentServedPoints,
                        won: serve.opponentServedPointsWon,
                        rate: serve.returnWinRate,
                        color: .purple,
                        subtitle: "Points won on opponent serve"
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }
}

struct ServeStatRow: View {
    let label: String
    let points: Int
    let won: Int
    let rate: Double
    let color: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(rate * 100))%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(rate), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(won) of \(points) points")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                if let sub = subtitle {
                    Spacer()
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Momentum Card
struct MomentumCard: View {
    let insights: GameInsightsResult

    private var momentum: MomentumInsights { insights.momentumInsights }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Momentum")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            // Momentum summary
            Text(momentum.momentumAdvantage)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 16) {
                MomentumStatBox(
                    value: "\(momentum.yourMaxStreak)",
                    label: "Your Best Run",
                    color: .green
                )
                MomentumStatBox(
                    value: "\(momentum.opponentMaxStreak)",
                    label: "Opponent's Run",
                    color: .red
                )
                MomentumStatBox(
                    value: "\(momentum.leadChanges)",
                    label: "Lead Changes",
                    color: .blue
                )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }
}

struct MomentumStatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Clutch Card
struct ClutchCard: View {
    let insights: GameInsightsResult

    private var clutch: ClutchInsights { insights.clutchInsights }
    private var isPickleball: Bool { insights.sportType == "Pickleball" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clutch Performance")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            if clutch.gamePointsPlayed > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isPickleball ? "Deuce Points (10-10+)" : "Deuce Points")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(clutch.gamePointsWon)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("/ \(clutch.gamePointsPlayed)")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Text("\(Int(clutch.clutchRate * 100))%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(clutch.clutchRate >= 0.5 ? .green : .red)
                }
            } else {
                Text("No clutch situations in this game")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }
}

// MARK: - No Data Card
struct NoDataCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("No Event Data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text("This game doesn't have point-by-point event data needed for serve insights.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }
}
