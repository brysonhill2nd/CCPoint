// WatchConnectivityManager.swift - Fixed version
import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isWatchReachable = false
    @Published var receivedGames: [WatchGameRecord] = []
    
    // Cloud sync manager
    private let cloudSync = UnifiedSyncManager.shared
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        loadGamesFromUserDefaults()
        
        // Sync existing games to cloud on startup
        Task {
            await syncExistingGamesToCloud()
        }
    }
    
    private func saveGamesToUserDefaults() {
        // Sort before saving to maintain order
        receivedGames.sort { $0.date > $1.date }
        if let encoded = try? JSONEncoder().encode(receivedGames) {
            UserDefaults.standard.set(encoded, forKey: "syncedGamesFromWatch")
        }
    }
    
    private func loadGamesFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "syncedGamesFromWatch"),
           let decoded = try? JSONDecoder().decode([WatchGameRecord].self, from: data) {
            receivedGames = decoded
        }
    }
    
    private func syncExistingGamesToCloud() async {
        // Only sync if we have games and user is authenticated
        guard !receivedGames.isEmpty,
              AuthenticationManager.shared.isAuthenticated else { return }
        
        print("📱 Syncing \(receivedGames.count) existing games to cloud...")
        await cloudSync.syncAllLocalGames(receivedGames)
    }
    
    func clearAllGames() {
        receivedGames.removeAll()
        saveGamesToUserDefaults()
        print("📱 All games cleared")
    }
    
    func games(for sport: SportFilter) -> [WatchGameRecord] {
        switch sport {
        case .all:
            return receivedGames
        case .pickleball:
            return receivedGames.filter {
                $0.sportType.lowercased().contains("pickleball") ||
                $0.sportType.lowercased().contains("pb")
            }
        case .tennis:
            return receivedGames.filter {
                $0.sportType.lowercased().contains("tennis") &&
                !$0.sportType.lowercased().contains("pickleball") &&
                !$0.sportType.lowercased().contains("pb")
            }
        case .padel:
            return receivedGames.filter {
                $0.sportType.lowercased().contains("padel") &&
                !$0.sportType.lowercased().contains("pickleball") &&
                !$0.sportType.lowercased().contains("pb")
            }
        }
    }
    
    var todaysGames: [WatchGameRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return receivedGames.filter {
            calendar.startOfDay(for: $0.date) == today
        }
    }
    
    var totalGamesCount: Int {
        receivedGames.count
    }
    
    var winCount: Int {
        receivedGames.filter { $0.winner == "You" }.count
    }
    
    var winPercentage: String {
        guard totalGamesCount > 0 else { return "0%" }
        let percentage = (Double(winCount) / Double(totalGamesCount)) * 100
        return "\(Int(percentage))%"
    }
    
    var last10Record: String {
        let last10 = Array(receivedGames.prefix(10))
        let wins = last10.filter { $0.winner == "You" }.count
        let losses = last10.count - wins
        return "\(wins)-\(losses)"
    }
    
    func addManualGame(_ game: WatchGameRecord) {
        receivedGames.insert(game, at: 0)
        saveGamesToUserDefaults()
        
        // Check achievements with new game
        checkAchievementsIfNeeded()
        
        // Sync to cloud immediately
        Task {
            await cloudSync.saveGame(game)
        }
        
        // Also send to watch if reachable
        if WCSession.default.isReachable {
            // Logic to send manual game to watch...
        }
    }
    
    // Fetch games from cloud
    func refreshFromCloud() async {
        let cloudGames = await cloudSync.fetchAllGames(limit: 100)
        
        await MainActor.run {
            // Merge with existing games, avoiding duplicates
            var gameIds = Set(self.receivedGames.map { $0.id })
            
            for game in cloudGames {
                if !gameIds.contains(game.id) {
                    self.receivedGames.append(game)
                    gameIds.insert(game.id)
                }
            }
            
            // Sort by date and save
            self.saveGamesToUserDefaults()
        }
    }
    
    // MARK: - Achievement Checking
    private func checkAchievementsIfNeeded() {
        if AuthenticationManager.shared.isAuthenticated,
           let user = AuthenticationManager.shared.currentUser {
            AchievementManager.shared.checkAchievements(
                for: receivedGames,
                user: user
            )
        }
    }

    // Update checkForPendingData to be more robust:
    func checkForPendingData() {
        guard WCSession.isSupported() && WCSession.default.activationState == .activated else {
            return
        }
        let context = WCSession.default.applicationContext
        if !context.isEmpty {
            print("📱 DEBUG: Found pending applicationContext. Processing...")
            self.session(WCSession.default, didReceiveApplicationContext: context)
        }
    }

    // Also add a public method to manually check for pending data:
    func manualCheckForPendingData() {
        print("📱 Manual check for pending data triggered")
        checkForPendingData()
    }
    
    /// This is the new, primary method for processing all game data from the Watch.
    private func processGameData(_ data: [String: Any]) {
        print("📱 iPhone: Processing game data...")
        
        // Extract game data
        guard let dateTimestamp = data["date"] as? TimeInterval,
              let gameType = data["gameType"] as? String,
              let player1Score = data["player1Score"] as? Int,
              let player2Score = data["player2Score"] as? Int else {
            print("❌ iPhone: Missing required game data fields")
            return
        }
        
        // Process events if available
        var gameEvents: [GameEventData]? = nil
        if let eventsArray = data["events"] as? [[String: Any]] {
            gameEvents = eventsArray.compactMap { eventDict in
                guard let timestamp = eventDict["timestamp"] as? TimeInterval,
                      let p1Score = eventDict["player1Score"] as? Int,
                      let p2Score = eventDict["player2Score"] as? Int,
                      let scoringPlayer = eventDict["scoringPlayer"] as? String,
                      let isServePoint = eventDict["isServePoint"] as? Bool else {
                    return nil
                }
                
                return GameEventData(
                    timestamp: timestamp,
                    player1Score: p1Score,
                    player2Score: p2Score,
                    scoringPlayer: scoringPlayer,
                    isServePoint: isServePoint
                )
            }
        }
        
        // Process health data if available
        var healthData: WatchGameHealthData? = nil
        if let healthDict = data["healthData"] as? [String: Any],
           let avgHR = healthDict["averageHeartRate"] as? Double,
           let calories = healthDict["totalCalories"] as? Double {
            healthData = WatchGameHealthData(averageHeartRate: avgHR, totalCalories: calories)
        }
        
        // Process set history if available (for Tennis/Padel)
        var setHistory: [WatchSetScore]? = nil
        if let setHistoryArray = data["setHistory"] as? [[String: Any]] {
            setHistory = setHistoryArray.compactMap { setDict in
                guard let p1Games = setDict["player1Games"] as? Int,
                      let p2Games = setDict["player2Games"] as? Int else {
                    return nil
                }
                
                var tiebreakScore: (Int, Int)? = nil
                if let tb1 = setDict["tiebreakPlayer1"] as? Int,
                   let tb2 = setDict["tiebreakPlayer2"] as? Int {
                    tiebreakScore = (tb1, tb2)
                }
                
                return WatchSetScore(
                    player1Games: p1Games,
                    player2Games: p2Games,
                    tiebreakScore: tiebreakScore
                )
            }
            print("📱 iPhone: Processed \(setHistory?.count ?? 0) sets")
        }
        
        // Create WatchGameRecord - FIXED: Added setHistory parameter
        let game = WatchGameRecord(
            id: UUID(uuidString: data["id"] as? String ?? "") ?? UUID(),
            date: Date(timeIntervalSince1970: dateTimestamp),
            sportType: data["sportType"] as? String ?? "Pickleball",
            gameType: gameType,
            player1Score: player1Score,
            player2Score: player2Score,
            player1GamesWon: data["player1GamesWon"] as? Int ?? 0,
            player2GamesWon: data["player2GamesWon"] as? Int ?? 0,
            elapsedTime: data["elapsedTime"] as? TimeInterval ?? 0,
            winner: data["winner"] as? String,
            location: nil,
            events: gameEvents,
            healthData: healthData,
            setHistory: setHistory  // ADDED: Include set history
        )
        
        DispatchQueue.main.async {
            // Check if game already exists using its unique ID
            if !self.receivedGames.contains(where: { $0.id == game.id }) {
                self.receivedGames.insert(game, at: 0)
                self.saveGamesToUserDefaults()
                self.checkAchievementsIfNeeded()
                
                // Sync to Firebase/Cloud
                Task {
                    await self.cloudSync.saveGame(game)
                }
                
                print("✅ iPhone: Added new game with ID \(game.id). Total games: \(self.receivedGames.count)")
            } else {
                print("⚠️ iPhone: Game with ID \(game.id) already exists, skipping.")
            }
        }
    }

    // NEW METHOD: Process game data with health info
    private func processGameDataWithHealth(_ data: [String: Any], healthData: WatchGameHealthData?) {
        print("📱 iPhone: Processing game data with health info...")
        
        // Generate a unique ID for this game
        let gameId = UUID()
        
        // Extract game data
        guard let sportType = data["sportType"] as? String,
              let gameType = data["gameType"] as? String,
              let player1Score = data["player1Score"] as? Int,
              let player2Score = data["player2Score"] as? Int else {
            print("❌ iPhone: Missing required game data fields")
            return
        }
        
        // Process events if available
        var gameEvents: [GameEventData]? = nil
        if let eventsArray = data["events"] as? [[String: Any]] {
            gameEvents = eventsArray.compactMap { eventDict in
                guard let timestamp = eventDict["timestamp"] as? TimeInterval,
                      let p1Score = eventDict["player1Score"] as? Int,
                      let p2Score = eventDict["player2Score"] as? Int,
                      let scoringPlayer = eventDict["scoringPlayer"] as? String,
                      let isServePoint = eventDict["isServePoint"] as? Bool else {
                    return nil
                }
                
                return GameEventData(
                    timestamp: timestamp,
                    player1Score: p1Score,
                    player2Score: p2Score,
                    scoringPlayer: scoringPlayer,
                    isServePoint: isServePoint
                )
            }
            print("📱 iPhone: Processed \(gameEvents?.count ?? 0) game events")
        }
        
        // Process set history if available (for Tennis/Padel)
        var setHistory: [WatchSetScore]? = nil
        if let setHistoryArray = data["setHistory"] as? [[String: Any]] {
            setHistory = setHistoryArray.compactMap { setDict in
                guard let p1Games = setDict["player1Games"] as? Int,
                      let p2Games = setDict["player2Games"] as? Int else {
                    return nil
                }
                
                var tiebreakScore: (Int, Int)? = nil
                if let tb1 = setDict["tiebreakPlayer1"] as? Int,
                   let tb2 = setDict["tiebreakPlayer2"] as? Int {
                    tiebreakScore = (tb1, tb2)
                }
                
                return WatchSetScore(
                    player1Games: p1Games,
                    player2Games: p2Games,
                    tiebreakScore: tiebreakScore
                )
            }
            print("📱 iPhone: Processed \(setHistory?.count ?? 0) sets")
        }
        
        // Create WatchGameRecord - FIXED: Added setHistory parameter
        let game = WatchGameRecord(
            id: gameId,
            date: Date(timeIntervalSince1970: data["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970),
            sportType: sportType,
            gameType: gameType,
            player1Score: player1Score,
            player2Score: player2Score,
            player1GamesWon: data["player1GamesWon"] as? Int ?? 0,
            player2GamesWon: data["player2GamesWon"] as? Int ?? 0,
            elapsedTime: data["elapsedTime"] as? TimeInterval ?? 0,
            winner: data["winner"] as? String,
            location: nil,
            events: gameEvents,
            healthData: healthData,
            setHistory: setHistory  // ADDED: Include set history
        )
        
        // Add to received games (prevent duplicates)
        if !self.receivedGames.contains(where: {
            $0.date == game.date &&
            $0.player1Score == game.player1Score &&
            $0.player2Score == game.player2Score
        }) {
            self.receivedGames.insert(game, at: 0)
            self.saveGamesToUserDefaults()
            self.checkAchievementsIfNeeded()
            
            // Sync to Firebase/Cloud
            Task {
                await self.cloudSync.saveGame(game)
            }
            
            print("✅ iPhone: Added new game with health data. Total games: \(self.receivedGames.count)")
        } else {
            print("⚠️ iPhone: Similar game already exists, skipping")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("📱 DEBUG: WatchConnectivity activated. Reachable: \(session.isReachable)")
            
            if activationState == .activated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.checkForPendingData()
                }
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 iOS: Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 iOS: Session deactivated")
        session.activate()
    }
    
    // FIXED: Now handles both "gameCompleted" and "newGame" messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 iOS: Received message from watch!")
        print("📱 iOS: Message keys: \(message.keys)")
        
        // Handle game completion message (what your Watch actually sends)
        if let gameData = message["gameCompleted"] as? [String: Any] {
            print("📱 iOS: Processing gameCompleted message")
            
            // Extract health data if present
            var healthData: WatchGameHealthData? = nil
            if let healthDict = message["healthData"] as? [String: Any],
               let avgHR = healthDict["averageHeartRate"] as? Double,
               let calories = healthDict["totalCalories"] as? Double {
                healthData = WatchGameHealthData(averageHeartRate: avgHR, totalCalories: calories)
                print("📱 iOS: Found health data - HR: \(avgHR), Cal: \(calories)")
            }
            
            // Process the game data with health info
            DispatchQueue.main.async {
                self.processGameDataWithHealth(gameData, healthData: healthData)
                replyHandler(["status": "success", "message": "Game processed successfully"])
            }
        } else if let gameData = message["newGame"] as? [String: Any] {
            // Keep backward compatibility
            DispatchQueue.main.async {
                self.processGameData(gameData)
                replyHandler(["status": "success", "message": "Processed newGame"])
            }
        } else {
            // Unknown message type
            print("📱 iOS: Unknown message format")
            replyHandler(["status": "error", "message": "Unknown message type"])
        }
    }
    
    // Add non-reply handler version too
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📱 iOS: Received message without reply handler")
        
        if let gameData = message["gameCompleted"] as? [String: Any] {
            var healthData: WatchGameHealthData? = nil
            if let healthDict = message["healthData"] as? [String: Any],
               let avgHR = healthDict["averageHeartRate"] as? Double,
               let calories = healthDict["totalCalories"] as? Double {
                healthData = WatchGameHealthData(averageHeartRate: avgHR, totalCalories: calories)
            }
            
            DispatchQueue.main.async {
                self.processGameDataWithHealth(gameData, healthData: healthData)
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📱 DEBUG: Received applicationContext update with keys: \(applicationContext.keys)")
        
        // Handle game data sent via context
        if let gameData = applicationContext["latestGame"] as? [String: Any] {
            DispatchQueue.main.async {
                self.processGameData(gameData)
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            print("📱 iOS: Watch reachability changed: \(session.isReachable)")
        }
    }
}
