//
//  GameEvent.swift
//  Point 
//
//  Created by Bryson Hill II on 6/27/25.
//

import Foundation

// MARK: - Game Events for Tracking
struct GameEvent {
    let timestamp: TimeInterval
    let player1Score: Int
    let player2Score: Int
    let scoringPlayer: Player
    let isServePoint: Bool
    let shotType: ShotType?
}


// MARK: - Game Insights Model
struct GameInsights {
    let events: [GameEvent]
    let finalScore: (player1: Int, player2: Int)
    let winner: Player
    let duration: TimeInterval
    
    // MARK: - Computed Insights
    
    var leadChanges: Int {
        var changes = 0
        var lastLeader: Player? = nil
        
        for event in events {
            let currentLeader: Player? = {
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
    
    var maxLead: Int {
        events.map { abs($0.player1Score - $0.player2Score) }.max() ?? 0
    }
    
    var comebackSize: Int {
        var maxDeficit = 0
        for event in events {
            let deficit = winner == .player1 ? 
                event.player2Score - event.player1Score : 
                event.player1Score - event.player2Score
            maxDeficit = max(maxDeficit, deficit)
        }
        return maxDeficit
    }
    
    var longestRun: (player: Player, points: Int) {
        var currentRun = 0
        var currentPlayer: Player? = nil
        var maxRun = 0
        var maxRunPlayer: Player = .player1
        
        for i in 1..<events.count {
            let scorer = events[i].scoringPlayer
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
        let pointsInLead = events.filter { 
            winner == .player1 ? $0.player1Score > $0.player2Score : $0.player2Score > $0.player1Score
        }.count
        return Int((Double(pointsInLead) / Double(events.count)) * 100)
    }
    
    var neverTrailed: Bool {
        let trailed = events.contains { event in
            winner == .player1 ? event.player1Score < event.player2Score : event.player2Score < event.player1Score
        }
        return !trailed
    }
    
    var closedOutStrong: Bool {
        guard events.count >= 3 else { return false }
        let lastThree = events.suffix(3)
        return lastThree.allSatisfy { $0.scoringPlayer == winner }
    }
    
    // MARK: - Game Story Generation
    
    var gameStory: GameStory {
        // Determine game type
        let gameType: GameStoryType = {
            if maxLead >= 5 && percentageInLead >= 70 {
                return .dominant
            } else if comebackSize >= 4 {
                return .comeback
            } else if finalScore.player1 != 0 && abs(finalScore.player1 - finalScore.player2) <= 2 {
                return .nailBiter
            } else if leadChanges >= 5 {
                return .backAndForth
            } else if neverTrailed {
                return .wireToWire
            } else {
                return .standard
            }
        }()
        
        return GameStory(
            type: gameType,
            headline: gameType.headline,
            moments: generateKeyMoments(),
            insights: generateInsights()
        )
    }
    
    private func generateKeyMoments() -> [StoryMoment] {
        var moments: [StoryMoment] = []
        
        // Opening
        if events.count >= 5 {
            let firstFive = events.prefix(6) // Including 0-0
            let player1Early = firstFive.filter { $0.scoringPlayer == .player1 }.count
            let player2Early = firstFive.filter { $0.scoringPlayer == .player2 }.count
            
            if player1Early >= 4 {
                moments.append(.hotStart(player: .player1, score: "5-1"))
            } else if player2Early >= 4 {
                moments.append(.hotStart(player: .player2, score: "1-5"))
            }
        }
        
        // Comeback moments
        if comebackSize >= 4 {
            let comebackScore = findComebackMoment()
            moments.append(.comeback(from: comebackScore, player: winner))
        }
        
        // Clutch finish
        if closedOutStrong && abs(finalScore.player1 - finalScore.player2) <= 2 {
            moments.append(.clutchFinish(score: "\(finalScore.player1)-\(finalScore.player2)"))
        }
        
        // Long runs
        let run = longestRun
        if run.points >= 5 {
            moments.append(.pointStreak(player: run.player, points: run.points))
        }
        
        return moments
    }
    
    private func generateInsights() -> [String] {
        var insights: [String] = []
        
        // Lead percentage
        if percentageInLead >= 80 {
            insights.append("Led \(percentageInLead)% of the game")
        } else if percentageInLead <= 20 {
            insights.append("Trailed most of the game")
        }
        
        // Lead changes
        if leadChanges >= 6 {
            insights.append("Lead changed \(leadChanges) times!")
        }
        
        // Never trailed
        if neverTrailed {
            insights.append("Never trailed")
        }
        
        // Dominant win
        if abs(finalScore.player1 - finalScore.player2) >= 5 {
            insights.append("Dominant \(abs(finalScore.player1 - finalScore.player2)) point victory")
        }
        
        // Close game
        if abs(finalScore.player1 - finalScore.player2) <= 2 {
            insights.append("Decided by \(abs(finalScore.player1 - finalScore.player2)) point\(abs(finalScore.player1 - finalScore.player2) == 1 ? "" : "s")")
        }
        
        return insights
    }
    
    private func findComebackMoment() -> String {
        var maxDeficit = 0
        var deficitScore = "0-0"
        
        for event in events {
            let deficit = winner == .player1 ? 
                event.player2Score - event.player1Score : 
                event.player1Score - event.player2Score
            
            if deficit > maxDeficit {
                maxDeficit = deficit
                deficitScore = "\(event.player1Score)-\(event.player2Score)"
            }
        }
        
        return deficitScore
    }
}

// MARK: - Story Types and Moments
enum GameStoryType {
    case dominant
    case comeback
    case nailBiter
    case backAndForth
    case wireToWire
    case standard
    
    var headline: String {
        switch self {
        case .dominant: return "⚡ Dominant Performance"
        case .comeback: return "🔥 Epic Comeback"
        case .nailBiter: return "😰 Nail-biter!"
        case .backAndForth: return "⚔️ Epic Battle"
        case .wireToWire: return "💪 Wire-to-Wire Win"
        case .standard: return "🏓 Good Win"
        }
    }
}

enum StoryMoment {
    case hotStart(player: Player, score: String)
    case comeback(from: String, player: Player)
    case clutchFinish(score: String)
    case pointStreak(player: Player, points: Int)
    case dominantStretch(score: String)
    
    var icon: String {
        switch self {
        case .hotStart: return "🔥"
        case .comeback: return "💪"
        case .clutchFinish: return "🎯"
        case .pointStreak: return "⚡"
        case .dominantStretch: return "👑"
        }
    }
    
    var description: String {
        switch self {
        case .hotStart(let player, let score):
            return "Hot start! Led \(score)"
        case .comeback(let from, let player):
            return "Incredible comeback from \(from)"
        case .clutchFinish(let score):
            return "Clutch finish at \(score)"
        case .pointStreak(let player, let points):
            return "\(points) point run!"
        case .dominantStretch(let score):
            return "Dominated at \(score)"
        }
    }
}

struct GameStory {
    let type: GameStoryType
    let headline: String
    let moments: [StoryMoment]
    let insights: [String]
}
