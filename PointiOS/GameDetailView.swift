//
//  GameDetailView.swift
//  PointiOS
//
//  Clean, Modern Game Detail View for iOS
//

import SwiftUI
import Lucide

struct GameDetailView: View {
    let game: WatchGameRecord
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: DetailTab = .overview
    @State private var showingPointByPoint = false
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case points = "Points"
    }
    
    // Generate insights from game data
    private var insights: GameInsights? {
        guard let events = game.events, !events.isEmpty else { return nil }
        
        let gameEvents = events.map { event in
            GameEvent(
                timestamp: event.timestamp,
                player1Score: event.player1Score,
                player2Score: event.player2Score,
                scoringPlayer: event.scoringPlayer == "player1" ? .player1 : .player2,
                isServePoint: event.isServePoint
            )
        }
        
        return GameInsights(
            events: gameEvents,
            finalScore: (player1: game.player1Score, player2: game.player2Score),
            winner: game.winner == "You" ? .player1 : .player2,
            duration: game.elapsedTime
        )
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
                        OverviewContent(game: game, insights: insights)
                    case .points:
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
    }
}

// MARK: - Tab Selector
struct TabSelector: View {
    @Binding var selectedTab: GameDetailView.DetailTab
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(GameDetailView.DetailTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedTab == tab ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.white.opacity(0.15) : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Overview Content
struct OverviewContent: View {
    let game: WatchGameRecord
    let insights: GameInsights?
    @State private var showingShareSheet = false

    var body: some View {
        VStack(spacing: 24) {
            // Score Card
            ScoreCard(game: game)

            // Stats Grid - Moved from separate Stats tab
            if let insights = insights {
                StatsGrid(insights: insights)
            }

            // Action Buttons
            ActionButtons(game: game, showingShareSheet: $showingShareSheet)
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(game: game)
        }
    }
}

// MARK: - Action Buttons
struct ActionButtons: View {
    let game: WatchGameRecord
    @Binding var showingShareSheet: Bool

    var body: some View {
        // Share Session Button
        Button(action: { showingShareSheet = true }) {
            HStack(spacing: 8) {
                Image(icon: .share2)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("Share Session")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: View {
    let game: WatchGameRecord
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share your game results")
                    .font(.title2)
                    .padding()

                Text("Score: \(game.player1Score) - \(game.player2Score)")
                    .font(.title)

                Text(game.winner == "You" ? "Victory!" : "Better luck next time")
                    .foregroundColor(game.winner == "You" ? .green : .red)

                Spacer()

                Button("Share") {
                    // TODO: Implement actual share functionality
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Share Game")
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }
}

// MARK: - Score Card
struct ScoreCard: View {
    let game: WatchGameRecord
    
    var body: some View {
        VStack(spacing: 32) {
            // Sport Header
            HStack(spacing: 16) {
                Text(game.sportEmoji)
                    .font(.system(size: 40))
                
                Text("\(game.sportType) \(game.gameType)")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.top, 8)
            
            // Main Score Display
            if game.sportType == "Tennis" || game.sportType == "Padel" {
                TennisScoreView(game: game)
            } else {
                PickleballScoreView(game: game)
            }
            
            // Result Badge
            Text(game.winner == "You" ? "Victory" : "Defeat")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(game.winner == "You" ? .green : .red)
                .padding(.vertical, 8)
            
            // Meta Info - Clean horizontal layout
            HStack(spacing: 32) {
                // Date
                VStack(spacing: 6) {
                    Image(icon: .calendar)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.gray)
                    Text(game.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                // Time
                VStack(spacing: 6) {
                    Image(icon: .clock)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.gray)
                    Text(game.elapsedTimeDisplay)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                // Health data if available
                if let health = game.healthData {
                    VStack(spacing: 6) {
                        Image(icon: .heart)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.red)
                        Text("\(Int(health.averageHeartRate)) bpm")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }

                    VStack(spacing: 6) {
                        Image(icon: .flame)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.orange)
                        Text("\(Int(health.totalCalories)) cal")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .cornerRadius(24)
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
struct StatsGrid: View {
    let insights: GameInsights

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCardLarge(
                icon: .trendingUp,
                iconColor: Color(red: 0.231, green: 0.510, blue: 0.965),
                value: "\(insights.maxLead)",
                title: "Max Lead"
            )

            StatCardLarge(
                icon: .arrowLeftRight,
                iconColor: Color(red: 0.961, green: 0.620, blue: 0.043),
                value: "\(insights.leadChanges)",
                title: "Lead Changes"
            )

            StatCardLarge(
                icon: .flame,
                iconColor: Color(red: 0.925, green: 0.282, blue: 0.600),
                value: "\(insights.longestRun.points)",
                title: "Longest Run"
            )

            StatCardLarge(
                icon: .activity,
                iconColor: Color(red: 0.063, green: 0.725, blue: 0.506),
                value: "\(insights.percentageInLead)%",
                title: "Time in Lead"
            )
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
    let icon: LucideIcon
    let iconColor: Color
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                Image(icon: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(iconColor)
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Points Content
struct PointsContent: View {
    let game: WatchGameRecord
    @State private var expandedGames: Set<Int> = [0] // First game expanded by default

    var body: some View {
        VStack(spacing: 16) {
            if let events = game.events, !events.isEmpty {
                // Check if this is a multi-game match
                if game.player1GamesWon > 0 || game.player2GamesWon > 0, let setHistory = game.setHistory {
                    // Multiple games - show expandable sections
                    ForEach(Array(setHistory.enumerated()), id: \.offset) { index, gameScore in
                        ExpandableGameCard(
                            gameNumber: index + 1,
                            playerScore: gameScore.player1Games,
                            opponentScore: gameScore.player2Games,
                            result: gameScore.player1Games > gameScore.player2Games ? "win" : "loss",
                            events: filterEventsForGame(events: events, gameIndex: index),
                            isExpanded: expandedGames.contains(index),
                            sportType: game.sportType,
                            gameType: game.gameType,
                            onToggle: {
                                if expandedGames.contains(index) {
                                    expandedGames.remove(index)
                                } else {
                                    expandedGames.insert(index)
                                }
                            }
                        )
                    }
                } else {
                    // Single game - show all points
                    ExpandableGameCard(
                        gameNumber: 1,
                        playerScore: game.player1Score,
                        opponentScore: game.player2Score,
                        result: game.winner == "You" ? "win" : "loss",
                        events: events,
                        isExpanded: true,
                        sportType: game.sportType,
                        gameType: game.gameType,
                        onToggle: {}
                    )
                }
            } else {
                VStack(spacing: 12) {
                    Image(icon: .trophy)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                        .padding(12)
                        .background(Circle().fill(Color.white.opacity(0.1)))

                    Text("No point data available")
                        .foregroundColor(.gray)

                    Text("Start recording points during your next game")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
        .padding(.horizontal, 20)
    }

    private func filterEventsForGame(events: [GameEventData], gameIndex: Int) -> [GameEventData] {
        // TODO: Implement logic to filter events by game
        // For now, return all events
        return events
    }
}

// MARK: - Expandable Game Card
struct ExpandableGameCard: View {
    let gameNumber: Int
    let playerScore: Int
    let opponentScore: Int
    let result: String
    let events: [GameEventData]
    let isExpanded: Bool
    let sportType: String
    let gameType: String
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header Button
            Button(action: onToggle) {
                HStack {
                    Text("Game \(gameNumber)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text("\(playerScore)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(result == "win" ? .green : .white)
                        Text("-")
                            .foregroundColor(.gray)
                        Text("\(opponentScore)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(result == "loss" ? .red : .white)
                    }

                    Text(result == "win" ? "Won" : "Lost")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(result == "win" ? .green : .red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(result == "win" ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        )

                    Spacer()

                    Image(icon: isExpanded ? .chevronUp : .chevronDown)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.gray)
                }
                .padding(20)
            }
            .background(Color.white.opacity(0.05))

            // Expanded Content
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        if index > 0 {  // Skip the initial 0-0 state
                            PointRowEnhanced(
                                event: event,
                                pointNumber: index,
                                previousEvent: index > 0 ? events[index - 1] : nil,
                                sportType: sportType,
                                gameType: gameType
                            )
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Point by Point Card
struct PointByPointCard: View {
    let game: WatchGameRecord
    let events: [GameEventData]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Point-by-Point Breakdown")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.up")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
            }
            .padding(24)
            
            // Points List - Skip initial 0-0
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    if index > 0 {  // Skip the initial 0-0 state
                        PointRow(
                            event: event,
                            pointNumber: index,
                            previousEvent: index > 0 ? events[index - 1] : nil,
                            sportType: game.sportType
                        )
                    }
                }
            }
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }
}

// MARK: - Point Row Enhanced with Server Indicators
struct PointRowEnhanced: View {
    let event: GameEventData
    let pointNumber: Int
    let previousEvent: GameEventData?
    let sportType: String
    let gameType: String

    var isSideOut: Bool {
        guard sportType == "Pickleball", let prev = previousEvent else { return false }
        // Side out when score doesn't change from previous event
        return event.player1Score == prev.player1Score &&
               event.player2Score == prev.player2Score
    }

    var whoScored: String? {
        guard let prev = previousEvent else { return nil }

        // Check if someone actually scored
        if event.player1Score > prev.player1Score {
            return "You"
        } else if event.player2Score > prev.player2Score {
            return "Opp"
        }

        return nil // No one scored (side out)
    }

    var serverInfo: (isPlayer: Bool, isS2: Bool) {
        // For doubles games, determine server position
        let isDoubles = gameType.lowercased().contains("doubles")
        let isPlayer = event.isServePoint

        // Simple logic: alternate between S1 and S2
        let isS2 = (event.player1Score + event.player2Score) % 2 == 1

        return (isPlayer, isDoubles && isS2)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Point number label
            Text("#\(pointNumber)")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.5))
                .frame(width: 35, alignment: .leading)

            // Score display
            HStack(spacing: 6) {
                Text("\(event.player1Score)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(whoScored == "You" ? .green : .white)

                Text("-")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)

                Text("\(event.player2Score)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(whoScored == "Opp" ? .red : .white)
            }
            .frame(width: 70)

            // Side out indicator (center)
            HStack(spacing: 0) {
                if isSideOut {
                    Text("Side Out")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.yellow)
                        )
                }
            }
            .frame(width: 80)

            Spacer()

            // Server indicators (right side)
            HStack(spacing: 4) {
                Circle()
                    .fill(serverInfo.isPlayer ? Color.green : Color.red)
                    .frame(width: 6, height: 6)

                if serverInfo.isS2 {
                    Circle()
                        .fill(serverInfo.isPlayer ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // Add divider between rows
        .overlay(alignment: .bottom) {
            Divider()
                .background(Color.white.opacity(0.05))
                .padding(.leading, 20)
        }
    }
}

// MARK: - Point Row
struct PointRow: View {
    let event: GameEventData
    let pointNumber: Int
    let previousEvent: GameEventData?
    let sportType: String

    var isSideOut: Bool {
        guard sportType == "Pickleball", let prev = previousEvent else { return false }
        // Side out when score doesn't change from previous event
        return event.player1Score == prev.player1Score &&
               event.player2Score == prev.player2Score
    }

    var whoScored: String? {
        guard let prev = previousEvent else { return nil }

        // Check if someone actually scored
        if event.player1Score > prev.player1Score {
            return "You"
        } else if event.player2Score > prev.player2Score {
            return "Opp"
        }

        return nil // No one scored (side out)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Point number label
            Text("#\(pointNumber)")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.5))
                .frame(width: 35, alignment: .leading)

            // Score display
            HStack(spacing: 6) {
                Text("\(event.player1Score)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(whoScored == "You" ? .green : .white)

                Text("-")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray)

                Text("\(event.player2Score)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(whoScored == "Opp" ? .red : .white)
            }
            .frame(width: 80, alignment: .leading)

            // Who scored (left-middle)
            if let scorer = whoScored {
                Text(scorer)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(scorer == "You" ? .green : .red)
                    .frame(width: 50)
            } else {
                Spacer()
                    .frame(width: 50)
            }

            Spacer()

            // Right side - Side out indicator only
            if isSideOut {
                Text("Side Out")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.yellow)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // Add divider between rows
        .overlay(alignment: .bottom) {
            Divider()
                .background(Color.white.opacity(0.05))
                .padding(.leading, 20)
        }
    }
}
