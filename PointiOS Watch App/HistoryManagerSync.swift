// HistoryManager+Sync.swift - Replace your current version with this

import Foundation

// MARK: - HistoryManager Extension with Health Support
extension HistoryManager {
    
    // Add this method to save games with health data
    func addGameWithHealth(_ gameState: GameState, sportType: String = "Pickleball", healthSummary: WorkoutSummary?) {
        print("⌚ HistoryManager: Saving game with health data...")
        
        let winnerString: String?
        if let winner = gameState.winner {
            winnerString = (winner == .player1) ? "You" : "Opponent"
        } else {
            winnerString = nil
        }

        var formatDesc = gameState.settings.matchFormatType.rawValue
        if gameState.settings.matchFormatType == .firstTo {
            formatDesc += " \(gameState.settings.firstToGamesCount)"
        }
        if let scoreLimit = gameState.settings.scoreLimit {
            formatDesc += ", \(scoreLimit) pts"
            if gameState.settings.winByTwo {
                formatDesc += " (Win by 2)"
            }
        } else {
            formatDesc += ", Unlimited pts"
        }
        
        // Convert game events
        let eventData: [GameEventData]? = gameState.gameEvents.isEmpty ? nil : gameState.gameEvents.map { event in
            GameEventData(
                timestamp: event.timestamp,
                player1Score: event.player1Score,
                player2Score: event.player2Score,
                scoringPlayer: event.scoringPlayer == .player1 ? "player1" : "player2",
                isServePoint: event.isServePoint
            )
        }
        
        // Create health data if available
        var healthData: GameRecord.HealthData? = nil
        if let health = healthSummary {
            healthData = GameRecord.HealthData(
                averageHeartRate: health.averageHeartRate,
                totalCalories: health.totalCalories
            )
            print("⌚ Including health data - HR: \(Int(health.averageHeartRate)), Cal: \(Int(health.totalCalories))")
        } else {
            print("⌚ No health data to include")
        }

        let record = GameRecord(
            id: UUID(),
            date: Date(),
            sportType: sportType,
            gameType: gameState.gameType == .singles ? "Singles" : "Doubles",
            player1Score: gameState.player1Score,
            player2Score: gameState.player2Score,
            player1GamesWon: gameState.player1GamesWon,
            player2GamesWon: gameState.player2GamesWon,
            elapsedTime: gameState.elapsedTime,
            matchFormatDescription: formatDesc,
            winner: winnerString,
            events: eventData,
            healthData: healthData,
            setHistory: nil// NOW INCLUDING HEALTH DATA!
        )

        history.insert(record, at: 0)
        saveHistory()
        
        print("⌚ Game saved with health data: \(healthData != nil)")
    }
    
    // Update this method to handle health data
    func addGameAndSync(_ gameState: GameState, sportType: String = "Pickleball") {
        Task {
            print("⌚ addGameAndSync starting...")
            
            // End health tracking and get summary
            let healthSummary = await gameState.endHealthTracking()
            print("⌚ Health summary obtained: \(healthSummary != nil)")
            
            // Add game with health data (not using basic addGame!)
            addGameWithHealth(gameState, sportType: sportType, healthSummary: healthSummary)
            
            // Send to phone with health data
            WatchConnectivityManager.shared.sendGameToPhoneWithHealth(
                gameState,
                sportType: sportType,
                healthSummary: healthSummary
            )
            
            WatchConnectivityManager.shared.lastSyncTime = Date()
        }
    }
    
}
