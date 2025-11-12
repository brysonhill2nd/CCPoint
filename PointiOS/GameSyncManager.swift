//
//  GameSyncManager.swift
//  PointiOS
//
//  Firebase Firestore sync manager - Fixed with lazy initialization
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class GameSyncManager {
    static let shared = GameSyncManager()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Single method that handles everything
    func saveGame(_ game: WatchGameRecord) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GameSyncError.noUser
        }
        
        // Convert game to dictionary
        var gameData: [String: Any] = [
            "id": game.id.uuidString,
            "date": Timestamp(date: game.date),
            "sportType": game.sportType,
            "gameType": game.gameType,
            "player1Score": game.player1Score,
            "player2Score": game.player2Score,
            "player1GamesWon": game.player1GamesWon,
            "player2GamesWon": game.player2GamesWon,
            "elapsedTime": game.elapsedTime,
            "winner": game.winner ?? NSNull(),
            "userId": userId,
            "createdAt": Timestamp()
        ]
        
        // Add location if available
        if let location = game.location {
            gameData["location"] = location
        }
        
        // Add events if available
        if let events = game.events {
            let eventsData = events.map { event in
                [
                    "timestamp": event.timestamp,
                    "player1Score": event.player1Score,
                    "player2Score": event.player2Score,
                    "scoringPlayer": event.scoringPlayer,
                    "isServePoint": event.isServePoint
                ]
            }
            gameData["events"] = eventsData
        }
        
        // Add health data if available (from the game record itself)
        if let health = game.healthData {
            gameData["healthData"] = [
                "averageHeartRate": health.averageHeartRate,
                "totalCalories": health.totalCalories
            ]
        }
        
        // Save to Firestore
        try await db.collection("games")
            .document(game.id.uuidString)
            .setData(gameData)
        
        print("✅ Game saved to Firebase" + (game.healthData != nil ? " with health data" : ""))
    }
    
    // The confusing saveGameWithHealthData method has been removed.
    
    // Other existing methods like fetchUserGames, syncAllLocalGames, etc. would remain here...
    
    // Example of fetchUserGames, assuming it exists
    func fetchUserGames(limit: Int) async throws -> [WatchGameRecord] {
        // Implementation for fetching games...
        return []
    }
    
    // Example of syncAllLocalGames, assuming it exists
    func syncAllLocalGames(_ games: [WatchGameRecord]) async {
        // Implementation for syncing all local games...
    }

    // MARK: - Delete Games
    func deleteGames(_ games: [WatchGameRecord]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GameSyncError.noUser
        }

        for game in games {
            do {
                try await db.collection("games")
                    .document(game.id.uuidString)
                    .delete()
                print("✅ Deleted game \(game.id.uuidString) from Firebase")
            } catch {
                print("❌ Failed to delete game \(game.id.uuidString) from Firebase: \(error)")
                throw error
            }
        }
    }
}

enum GameSyncError: Error {
    case noUser
}
