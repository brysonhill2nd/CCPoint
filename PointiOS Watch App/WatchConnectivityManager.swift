// WatchConnectivityManager.swift - Add this to your WATCH APP

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isPhoneReachable = false
    @Published var lastSyncTime: Date?
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // Add this method
    func checkForPendingData() {
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        let context = session.applicationContext
        
        if context.isEmpty {
            print("⌚ No pending sync data found")
        } else {
            print("⌚ Found pending sync data: \(context.keys)")
            // The iPhone will pick this up when it launches
        }
    }

    /// This method has been added from your second code block.
    func sendGameToPhone(_ game: GameRecord) {
        print("📤 Watch: Sending game to iPhone...")
        
        guard WCSession.isSupported() && WCSession.default.activationState == .activated else {
            print("❌ Watch: WCSession not ready")
            return
        }
        
        let session = WCSession.default
        
        // Create game data dictionary including events
        var gameData: [String: Any] = [
            "type": "newGame",
            "id": game.id.uuidString,
            "date": game.date.timeIntervalSince1970,
            "gameType": game.gameType,
            "player1Score": game.player1Score,
            "player2Score": game.player2Score,
            "player1GamesWon": game.player1GamesWon,
            "player2GamesWon": game.player2GamesWon,
            "elapsedTime": game.elapsedTime,
            "winner": game.winner ?? "",
            "sportType": game.sportType,
            "matchFormatDescription": game.matchFormatDescription
        ]
        
        // Add events if available
        if let events = game.events, !events.isEmpty {
            let eventsArray = events.map { event in
                return [
                    "timestamp": event.timestamp,
                    "player1Score": event.player1Score,
                    "player2Score": event.player2Score,
                    "scoringPlayer": event.scoringPlayer,
                    "isServePoint": event.isServePoint
                ]
            }
            gameData["events"] = eventsArray
            print("📤 Watch: Including \(events.count) events")
        }
        
        // Add health data if available
        if let healthData = game.healthData {
            gameData["healthData"] = [
                "averageHeartRate": healthData.averageHeartRate,
                "totalCalories": healthData.totalCalories
            ]
        }
        
        // Send via application context (most reliable)
        do {
            try session.updateApplicationContext(["latestGame": gameData])
            print("✅ Watch: Sent game with events via context")
        } catch {
            print("❌ Watch: Failed to send: \(error)")
        }
    }
    
    // Your existing sendGameToPhone method
    func sendGameToPhone(_ gameState: GameState, sportType: String = "Pickleball") {
        sendGameToPhoneWithHealth(gameState, sportType: sportType, healthSummary: nil)
    }

    // Your existing sendGameToPhoneWithHealth method
    func sendGameToPhoneWithHealth(_ gameState: GameState, sportType: String = "Pickleball", healthSummary: WorkoutSummary?) {
        print("⌚ DEBUG: sendGameToPhoneWithHealth called")
        print("⌚ DEBUG: WCSession.isSupported: \(WCSession.isSupported())")
        print("⌚ DEBUG: WCSession.default.isReachable: \(WCSession.default.isReachable)")
        print("⌚ DEBUG: WCSession.default.activationState: \(WCSession.default.activationState.rawValue)")
        
        guard WCSession.default.isReachable else {
            print("⌚ ERROR: Phone not reachable!")
            tryOfflineSync(gameState: gameState, sportType: sportType, healthSummary: healthSummary)
            return
        }
        
        // Convert events to sendable format
        let events = gameState.gameEvents.map { event in
            [
                "timestamp": event.timestamp,
                "player1Score": event.player1Score,
                "player2Score": event.player2Score,
                "scoringPlayer": event.scoringPlayer == Player.player1 ? "player1" : "player2",
                "isServePoint": event.isServePoint
            ]
        }
        
        let gameData: [String: Any] = [
            "sportType": sportType,
            "gameType": gameState.gameType == .singles ? "Singles" : "Doubles",
            "player1Score": gameState.player1Score,
            "player2Score": gameState.player2Score,
            "player1GamesWon": gameState.player1GamesWon,
            "player2GamesWon": gameState.player2GamesWon,
            "elapsedTime": gameState.elapsedTime,
            "winner": gameState.winner == .player1 ? "You" : (gameState.winner == .player2 ? "Opponent" : nil) as Any,
            "timestamp": Date().timeIntervalSince1970,
            "events": events
        ]
        
        var message: [String: Any] = ["gameCompleted": gameData]
        
        // Add health data if available
        if let health = healthSummary {
            let healthDict: [String: Any] = [
                "averageHeartRate": health.averageHeartRate,
                "totalCalories": health.totalCalories
            ]
            message["healthData"] = healthDict
            print("⌚ DEBUG: Sending health data: \(healthDict)")
        } else {
            print("⌚ DEBUG: No health summary to send")
        }
        
        print("⌚ DEBUG: Attempting to send message...")
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            print("⌚ SUCCESS: Message sent and acknowledged by phone")
            print("⌚ DEBUG: Response: \(response)")
            DispatchQueue.main.async {
                self.lastSyncTime = Date()
            }
        }) { error in
            print("⌚ ERROR: Failed to send - \(error.localizedDescription)")
            self.tryOfflineSync(gameState: gameState, sportType: sportType, healthSummary: healthSummary)
        }
    }

    // Updated tryOfflineSync method with more debugging
    private func tryOfflineSync(gameState: GameState, sportType: String, healthSummary: WorkoutSummary?) {
        print("⌚ DEBUG: Attempting offline sync using applicationContext")

        // First, let's check what's currently in the context
        let currentContext = WCSession.default.applicationContext
        print("⌚ DEBUG: Current context before update: \(currentContext)")

        // Convert events to sendable format
        let events = gameState.gameEvents.map { event in
            [
                "timestamp": event.timestamp,
                "player1Score": event.player1Score,
                "player2Score": event.player2Score,
                "scoringPlayer": event.scoringPlayer == Player.player1 ? "player1" : "player2",
                "isServePoint": event.isServePoint
            ]
        }

        var context: [String: Any] = [
            "latestGame": [
                "id": UUID().uuidString,
                "sportType": sportType,
                "gameType": gameState.gameType == .singles ? "Singles" : "Doubles",
                "player1Score": gameState.player1Score,
                "player2Score": gameState.player2Score,
                "player1GamesWon": gameState.player1GamesWon,
                "player2GamesWon": gameState.player2GamesWon,
                "elapsedTime": gameState.elapsedTime,
                "date": Date().timeIntervalSince1970,
                "winner": gameState.winner == .player1 ? "You" : (gameState.winner == .player2 ? "Opponent" : "None"),
                "events": events
            ]
        ]
        
        if let health = healthSummary {
            context["healthData"] = [
                "averageHeartRate": health.averageHeartRate,
                "totalCalories": health.totalCalories
            ]
        }
        
        print("⌚ DEBUG: Context to save: \(context)")

        do {
            try WCSession.default.updateApplicationContext(context)
            print("⌚ SUCCESS: Game saved to applicationContext for later sync")

            // Verify it was saved
            let newContext = WCSession.default.applicationContext
            print("⌚ DEBUG: Context after update: \(newContext)")
            print("⌚ DEBUG: Context has latestGame: \(newContext["latestGame"] != nil)")

            DispatchQueue.main.async {
                self.lastSyncTime = Date()
            }
        } catch {
            print("⌚ ERROR: Failed to update applicationContext - \(error)")
        }
    }

    // Your existing test methods...
    func sendPadelGameToPhone(_ gameState: PadelGameState) {
        print("Padel game sending logic would be here.")
    }

    func sendTennisGameToPhone(_ gameState: TennisGameState) {
        print("Tennis game sending logic would be here.")
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = (activationState == .activated && session.isReachable)
            print("⌚ Watch connectivity activated: \(self.isPhoneReachable)")
            // Check for pending data when the session activates
            self.checkForPendingData()
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            print("⌚ Phone reachability changed: \(self.isPhoneReachable)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚ Received message from phone: \(message)")
        // Handle messages from phone (like settings updates)
    }
}
