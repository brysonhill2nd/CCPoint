//
//  GameDetailView.swift
//  PointiOS
//
//  Clean, Modern Game Detail View for iOS
//

import SwiftUI

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
    
    var body: some View {
        VStack(spacing: 24) {
            // Score Card
            ScoreCard(game: game)
            
            // Stats Grid - Moved from separate Stats tab
            if let insights = insights {
                StatsGrid(insights: insights)
            }
        }
        .padding(.horizontal, 20)
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
            HStack(spacing: 40) {
                // Date
                VStack(spacing: 4) {
                    Text("📅")
                        .font(.system(size: 24))
                    Text(game.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                // Time
                VStack(spacing: 4) {
                    Text("⏱")
                        .font(.system(size: 24))
                    Text(game.elapsedTimeDisplay)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                // Health data if available
                if let health = game.healthData {
                    VStack(spacing: 4) {
                        Text("❤️")
                            .font(.system(size: 24))
                        Text("\(Int(health.averageHeartRate)) bpm")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 24))
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
        VStack(spacing: 16) {
            if let events = game.events, !events.isEmpty {
                PointByPointCard(game: game, events: events)
            } else {
                Text("No point data available")
                    .foregroundColor(.gray)
                    .padding(40)
            }
        }
        .padding(.horizontal, 20)
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
