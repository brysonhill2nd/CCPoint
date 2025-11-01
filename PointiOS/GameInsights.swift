//
//  GameInsights.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/23/25.
//


// GameInsights.swift - iOS Version
import Foundation

struct GameInsights {
    let events: [GameEvent]
    let finalScore: (player1: Int, player2: Int)
    let winner: Player
    let duration: TimeInterval
    
    var maxLead: Int {
        events.map { abs($0.player1Score - $0.player2Score) }.max() ?? 0
    }
    
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
    
    var comebackSize: Int {
        var maxDeficit = 0
        
        for event in events {
            if winner == .player1 && event.player2Score > event.player1Score {
                maxDeficit = max(maxDeficit, event.player2Score - event.player1Score)
            } else if winner == .player2 && event.player1Score > event.player2Score {
                maxDeficit = max(maxDeficit, event.player1Score - event.player2Score)
            }
        }
        
        return maxDeficit
    }
    
    var neverTrailed: Bool {
        guard winner == .player1 else { return false }
        
        for event in events {
            if event.player2Score > event.player1Score {
                return false
            }
        }
        return true
    }
    
    var gameStory: (headline: String, description: String) {
        // Wire-to-wire victory
        if neverTrailed && winner == .player1 {
            return ("Wire-to-Wire Victory! 🏆", 
                    "You dominated from start to finish, never letting your opponent take the lead.")
        }
        
        // Comeback victory
        if comebackSize >= 5 && winner == .player1 {
            return ("Epic Comeback! 💪", 
                    "You were down \(comebackSize) points but fought back to claim victory!")
        }
        
        // Blown lead loss
        if comebackSize >= 5 && winner == .player2 {
            return ("Couldn't Hold On 😔", 
                    "You had a \(comebackSize)-point lead but your opponent mounted an incredible comeback.")
        }
        
        // Dominant win
        if maxLead >= 7 && percentageInLead >= 80 && winner == .player1 {
            return ("Dominant Performance! 🔥", 
                    "You controlled the game from start to finish with a commanding \(maxLead)-point lead.")
        }
        
        // Close game
        if maxLead <= 3 {
            if winner == .player1 {
                return ("Nail-Biter Victory! 😅", 
                        "Every point mattered in this incredibly close match.")
            } else {
                return ("So Close! 😤", 
                        "A hard-fought battle that could have gone either way.")
            }
        }
        
        // Back and forth game
        if leadChanges >= 5 {
            if winner == .player1 {
                return ("Battle of Wills! ⚔️", 
                        "Back and forth \(leadChanges) times, but you had the final say!")
            } else {
                return ("Tough Battle 💔", 
                        "The lead changed \(leadChanges) times in this intense match.")
            }
        }
        
        // Default stories
        if winner == .player1 {
            return ("Nice Win! 👏", 
                    "A solid performance to secure the victory.")
        } else {
            return ("Better Luck Next Time 🎯", 
                    "Keep practicing and you'll get them next time!")
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}