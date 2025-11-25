// WatchConnectivityManager.swift - Fixed version
import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isWatchReachable = false
    @Published var receivedGames: [WatchGameRecord] = []
    @Published private(set) var lastCloudRefresh: Date?
    
    // Cloud sync manager
    private let cloudSync = UnifiedSyncManager.shared
    private let lastRefreshKey = "watchConnectivityLastCloudRefresh"
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        loadGamesFromUserDefaults()
        if let storedDate = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date {
            lastCloudRefresh = storedDate
        }
        
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

    private func updateLastRefreshDate() {
        let now = Date()
        lastCloudRefresh = now
        UserDefaults.standard.set(now, forKey: lastRefreshKey)
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

    func deleteGames(_ games: [WatchGameRecord]) {
        let gameIDsToDelete = Set(games.map { $0.id })
        receivedGames.removeAll { gameIDsToDelete.contains($0.id) }
        saveGamesToUserDefaults()
        print("📱 Deleted \(games.count) game(s)")

        // Delete from cloud storage
        Task {
            await cloudSync.deleteGames(games)
        }
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
            self.updateLastRefreshDate()
        }
    }

    func refreshFromCloudIfStale(maxAge: TimeInterval = 60 * 10) async {
        if let last = lastCloudRefresh, Date().timeIntervalSince(last) < maxAge {
            return
        }
        await refreshFromCloud()
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

    // MARK: - Settings Sync
    func syncSettingsToWatch() {
        guard WCSession.isSupported() && WCSession.default.activationState == .activated else {
            print("📱 WCSession not ready for settings sync")
            return
        }

        let settings = AppData().userSettings

        let settingsData: [String: Any] = [
            "pickleball": [
                "scoreLimit": settings.pickleballSettings.scoreLimit ?? 11,
                "winByTwo": settings.pickleballSettings.winByTwo,
                "matchFormat": settings.pickleballSettings.matchFormat,
                "preferredGameType": settings.pickleballSettings.preferredGameType
            ],
            "tennis": [
                "scoreLimit": settings.tennisSettings.scoreLimit ?? 0,
                "winByTwo": settings.tennisSettings.winByTwo,
                "matchFormat": settings.tennisSettings.matchFormat,
                "preferredGameType": settings.tennisSettings.preferredGameType
            ],
            "padel": [
                "scoreLimit": settings.padelSettings.scoreLimit ?? 0,
                "winByTwo": settings.padelSettings.winByTwo,
                "matchFormat": settings.padelSettings.matchFormat,
                "preferredGameType": settings.padelSettings.preferredGameType
            ]
        ]

        do {
            try WCSession.default.updateApplicationContext(["settings": settingsData])
            print("✅ iPhone: Settings synced to Watch")
        } catch {
            print("❌ iPhone: Failed to sync settings: \(error)")
        }
    }

    private func applySettingsFromWatch(_ settingsData: [String: Any]) {
        print("📱 iPhone: Applying settings from Watch")

        // Get the shared AppData instance
        // Note: This needs to be the same instance used by the UI
        // You may need to pass AppData as a parameter or use NotificationCenter

        if let pickleballData = settingsData["pickleball"] as? [String: Any] {
            var settings = AppData().userSettings.pickleballSettings

            if let scoreLimit = pickleballData["scoreLimit"] as? Int {
                settings.scoreLimit = scoreLimit
            }
            if let winByTwo = pickleballData["winByTwo"] as? Bool {
                settings.winByTwo = winByTwo
            }
            if let matchFormat = pickleballData["matchFormat"] as? String {
                // Map Watch format string to iPhone format
                if matchFormat.contains("Single") {
                    settings.matchFormat = "single"
                } else if matchFormat.contains("Best of 3") {
                    settings.matchFormat = "bestOf3"
                } else if matchFormat.contains("Best of 5") {
                    settings.matchFormat = "bestOf5"
                }
            }

            // Save updated settings
            AppData().userSettings.pickleballSettings = settings
            AppData().saveSettings()

            print("✅ iPhone: Settings applied from Watch")
        }
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
                let shotType = eventDict["shotType"] as? String
                
                return GameEventData(
                    timestamp: timestamp,
                    player1Score: p1Score,
                    player2Score: p2Score,
                    scoringPlayer: scoringPlayer,
                    isServePoint: isServePoint,
                    shotType: shotType
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

        // Process shots data if available
        var shots: [StoredShot]? = nil
        if let shotsArray = data["shots"] as? [[String: Any]] {
            shots = shotsArray.compactMap { shotDict in
                guard let idString = shotDict["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let typeString = shotDict["type"] as? String,
                      let type = ShotType(rawValue: typeString),
                      let intensity = shotDict["intensity"] as? Double,
                      let absoluteMagnitude = shotDict["absoluteMagnitude"] as? Double,
                      let timestamp = shotDict["timestamp"] as? TimeInterval,
                      let isPointCandidate = shotDict["isPointCandidate"] as? Bool,
                      let gyroAngle = shotDict["gyroAngle"] as? Double,
                      let swingDuration = shotDict["swingDuration"] as? TimeInterval,
                      let sport = shotDict["sport"] as? String,
                      let associatedWithPoint = shotDict["associatedWithPoint"] as? Bool else {
                    return nil
                }

                let rallyReactionTime = shotDict["rallyReactionTime"] as? TimeInterval
                let isBackhand = shotDict["isBackhand"] as? Bool ?? false

                return StoredShot(
                    id: id,
                    type: type,
                    intensity: intensity,
                    absoluteMagnitude: absoluteMagnitude,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    isPointCandidate: isPointCandidate,
                    gyroAngle: gyroAngle,
                    swingDuration: swingDuration,
                    sport: sport,
                    rallyReactionTime: rallyReactionTime,
                    associatedWithPoint: associatedWithPoint,
                    isBackhand: isBackhand
                )
            }
            print("📱 iPhone: Processed \(shots?.count ?? 0) shots")
        }

        // Create WatchGameRecord - FIXED: Added setHistory and shots parameters
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
            setHistory: setHistory,  // ADDED: Include set history
            shots: shots  // ADDED: Include shot tracking data
        )
        
        DispatchQueue.main.async {
            // Check if game already exists using its unique ID
            if !self.receivedGames.contains(where: { $0.id == game.id }) {
                self.receivedGames.insert(game, at: 0)
                self.saveGamesToUserDefaults()
                self.checkAchievementsIfNeeded()
                _ = XPManager.shared.awardXP(for: game)
                
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
                let shotType = eventDict["shotType"] as? String
                
                return GameEventData(
                    timestamp: timestamp,
                    player1Score: p1Score,
                    player2Score: p2Score,
                    scoringPlayer: scoringPlayer,
                    isServePoint: isServePoint,
                    shotType: shotType
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

        // Process shots data if available
        var shots: [StoredShot]? = nil
        if let shotsArray = data["shots"] as? [[String: Any]] {
            shots = shotsArray.compactMap { shotDict in
                guard let idString = shotDict["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let typeString = shotDict["type"] as? String,
                      let type = ShotType(rawValue: typeString),
                      let intensity = shotDict["intensity"] as? Double,
                      let absoluteMagnitude = shotDict["absoluteMagnitude"] as? Double,
                      let timestamp = shotDict["timestamp"] as? TimeInterval,
                      let isPointCandidate = shotDict["isPointCandidate"] as? Bool,
                      let gyroAngle = shotDict["gyroAngle"] as? Double,
                      let swingDuration = shotDict["swingDuration"] as? TimeInterval,
                      let sport = shotDict["sport"] as? String,
                      let associatedWithPoint = shotDict["associatedWithPoint"] as? Bool else {
                    return nil
                }

                let rallyReactionTime = shotDict["rallyReactionTime"] as? TimeInterval
                let isBackhand = shotDict["isBackhand"] as? Bool ?? false

                return StoredShot(
                    id: id,
                    type: type,
                    intensity: intensity,
                    absoluteMagnitude: absoluteMagnitude,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    isPointCandidate: isPointCandidate,
                    gyroAngle: gyroAngle,
                    swingDuration: swingDuration,
                    sport: sport,
                    rallyReactionTime: rallyReactionTime,
                    associatedWithPoint: associatedWithPoint,
                    isBackhand: isBackhand
                )
            }
            print("📱 iPhone: Processed \(shots?.count ?? 0) shots")
        }

        // Create WatchGameRecord - FIXED: Added setHistory and shots parameters
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
            setHistory: setHistory,  // ADDED: Include set history
            shots: shots  // ADDED: Include shot tracking data
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
            _ = XPManager.shared.awardXP(for: game)
            
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

        // Handle settings sync from Watch
        if let settingsData = applicationContext["settings"] as? [String: Any] {
            DispatchQueue.main.async {
                self.applySettingsFromWatch(settingsData)
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

#if DEBUG
extension WatchConnectivityManager {
    func loadSampleGames() {
        addSampleGames(SampleGameFactory.buildSamples())
    }
    
    func addSampleGames(_ games: [WatchGameRecord]) {
        var existing = Set(receivedGames.map { $0.id })
        let today = Date()
        for game in games {
            guard !existing.contains(game.id) else { continue }
            let newGame = WatchGameRecord(
                id: UUID(),
                date: today,
                sportType: game.sportType,
                gameType: game.gameType,
                player1Score: game.player1Score,
                player2Score: game.player2Score,
                player1GamesWon: game.player1GamesWon,
                player2GamesWon: game.player2GamesWon,
                elapsedTime: game.elapsedTime,
                winner: game.winner,
                location: game.location,
                events: game.events,
                healthData: game.healthData,
                setHistory: game.setHistory
            )
            receivedGames.insert(newGame, at: 0)
            existing.insert(newGame.id)
        }
        saveGamesToUserDefaults()
    }
}

private enum SampleGameFactory {
    private enum Participant {
        case player
        case opponent
    }
    
    private struct SamplePoint {
        let servedBy: Participant
        let wonBy: Participant
        let score: (player: Int, opponent: Int)
    }
    
    static func buildSamples() -> [WatchGameRecord] {
        [
            pickleballBlowoutWin(),
            pickleballBlowoutLoss(),
            pickleballCompetitiveGame(),
            pickleballThreeSetter(),
            padelThreeSetter(),
            tennisStraightSetsWin(),
            tennisTiebreakLoss()
        ]
    }
    
    private static func pickleballBlowoutWin() -> WatchGameRecord {
        let points = (1...11).map { idx in
            SamplePoint(servedBy: .player, wonBy: .player, score: (idx, 0))
        }
        return makeRecord(
            id: "00000000-0000-0000-0000-000000000001",
            isoDate: "2025-02-18T14:30:00Z",
            playerScore: 11,
            opponentScore: 0,
            gamesWon: (1, 0),
            winner: "You",
            points: points,
            elapsed: 360,
            calories: 280,
            avgHR: 110
        )
    }
    
    private static func pickleballBlowoutLoss() -> WatchGameRecord {
        let points = (1...11).map { idx in
            SamplePoint(servedBy: .opponent, wonBy: .opponent, score: (0, idx))
        }
        return makeRecord(
            id: "00000000-0000-0000-0000-000000000002",
            isoDate: "2025-02-18T15:00:00Z",
            playerScore: 0,
            opponentScore: 11,
            gamesWon: (0, 1),
            winner: "Opponent",
            points: points,
            elapsed: 320,
            calories: 250,
            avgHR: 108
        )
    }
    
    private static func pickleballCompetitiveGame() -> WatchGameRecord {
        let scores: [(Int, Int)] = [
            (1,0),(1,1),(2,1),(2,2),(3,2),(3,3),(4,3),(4,4),(5,4),(5,5),
            (6,5),(6,6),(7,6),(7,7),(8,7),(8,8),(9,8),(9,9),(10,9),(11,9)
        ]
        let points = scores.enumerated().map { idx, score -> SamplePoint in
            let playerScored = idx == 0 || score.0 > scores[max(idx-1,0)].0
            return SamplePoint(
                servedBy: playerScored ? .player : .opponent,
                wonBy: playerScored ? .player : .opponent,
                score: score
            )
        }
        return makeRecord(
            id: "00000000-0000-0000-0000-000000000003",
            isoDate: "2025-02-18T16:00:00Z",
            playerScore: 11,
            opponentScore: 9,
            gamesWon: (1, 0),
            winner: "You",
            points: points,
            elapsed: 720,
            calories: 360,
            avgHR: 118
        )
    }
    
    private static func pickleballThreeSetter() -> WatchGameRecord {
        let sets = [
            WatchSetScore(player1Games: 11, player2Games: 7, tiebreakScore: nil),
            WatchSetScore(player1Games: 9, player2Games: 11, tiebreakScore: nil),
            WatchSetScore(player1Games: 11, player2Games: 6, tiebreakScore: nil)
        ]
        return WatchGameRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011") ?? UUID(),
            date: Date(),
            sportType: "Pickleball",
            gameType: "Doubles",
            player1Score: 2,
            player2Score: 1,
            player1GamesWon: 2,
            player2GamesWon: 1,
            elapsedTime: 4200,
            winner: "You",
            location: "Hemingway",
            events: nil,
            healthData: WatchGameHealthData(averageHeartRate: 118, totalCalories: 480),
            setHistory: sets
        )
    }
    private static func tennisStraightSetsWin() -> WatchGameRecord {
        let sets = [
            WatchSetScore(player1Games: 6, player2Games: 3, tiebreakScore: nil),
            WatchSetScore(player1Games: 6, player2Games: 4, tiebreakScore: nil)
        ]
        let events: [GameEventData] = [
            GameEventData(timestamp: 15, player1Score: 1, player2Score: 0, scoringPlayer: "player1", isServePoint: true, shotType: "Serve"),
            GameEventData(timestamp: 60, player1Score: 2, player2Score: 0, scoringPlayer: "player1", isServePoint: false, shotType: "Volley"),
            GameEventData(timestamp: 140, player1Score: 2, player2Score: 1, scoringPlayer: "player2", isServePoint: true, shotType: "Drive"),
            GameEventData(timestamp: 220, player1Score: 3, player2Score: 1, scoringPlayer: "player1", isServePoint: true, shotType: "Serve"),
            GameEventData(timestamp: 320, player1Score: 4, player2Score: 1, scoringPlayer: "player1", isServePoint: false, shotType: "Smash")
        ]
        return WatchGameRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008") ?? UUID(),
            date: Date(),
            sportType: "Tennis",
            gameType: "Singles",
            player1Score: 2,
            player2Score: 0,
            player1GamesWon: 2,
            player2GamesWon: 0,
            elapsedTime: 4200,
            winner: "You",
            location: "Riverside Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 118, totalCalories: 420),
            setHistory: sets
        )
    }
    
    private static func tennisTiebreakLoss() -> WatchGameRecord {
        let sets = [
            WatchSetScore(player1Games: 6, player2Games: 4, tiebreakScore: nil),
            WatchSetScore(player1Games: 5, player2Games: 7, tiebreakScore: nil),
            WatchSetScore(player1Games: 6, player2Games: 7, tiebreakScore: (5, 7))
        ]
        let events: [GameEventData] = [
            GameEventData(timestamp: 30, player1Score: 1, player2Score: 0, scoringPlayer: "player1", isServePoint: true, shotType: "Serve"),
            GameEventData(timestamp: 90, player1Score: 1, player2Score: 1, scoringPlayer: "player2", isServePoint: true, shotType: "Drive"),
            GameEventData(timestamp: 180, player1Score: 2, player2Score: 1, scoringPlayer: "player1", isServePoint: false, shotType: "Volley"),
            GameEventData(timestamp: 300, player1Score: 2, player2Score: 2, scoringPlayer: "player2", isServePoint: false, shotType: "Smash"),
            GameEventData(timestamp: 420, player1Score: 2, player2Score: 3, scoringPlayer: "player2", isServePoint: true, shotType: "Serve")
        ]
        return WatchGameRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009") ?? UUID(),
            date: Date(),
            sportType: "Tennis",
            gameType: "Singles",
            player1Score: 1,
            player2Score: 2,
            player1GamesWon: 1,
            player2GamesWon: 2,
            elapsedTime: 5100,
            winner: "Opponent",
            location: "Central Park",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 125, totalCalories: 560),
            setHistory: sets
        )
    }
    
    private static func padelThreeSetter() -> WatchGameRecord {
        let sets = [
            WatchSetScore(player1Games: 6, player2Games: 4, tiebreakScore: nil),
            WatchSetScore(player1Games: 5, player2Games: 7, tiebreakScore: nil),
            WatchSetScore(player1Games: 6, player2Games: 3, tiebreakScore: nil)
        ]
        let events: [GameEventData] = [
            GameEventData(timestamp: 10, player1Score: 1, player2Score: 0, scoringPlayer: "player1", isServePoint: true, shotType: "Drive"),
            GameEventData(timestamp: 45, player1Score: 1, player2Score: 1, scoringPlayer: "player2", isServePoint: false, shotType: "Volley"),
            GameEventData(timestamp: 90, player1Score: 2, player2Score: 1, scoringPlayer: "player1", isServePoint: true, shotType: "Smash")
        ]
        return WatchGameRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010") ?? UUID(),
            date: Date(),
            sportType: "Padel",
            gameType: "Doubles",
            player1Score: 2,
            player2Score: 1,
            player1GamesWon: 2,
            player2GamesWon: 1,
            elapsedTime: 5800,
            winner: "You",
            location: "Downtown Sports Complex",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 122, totalCalories: 640),
            setHistory: sets
        )
    }
    
    private static func makeRecord(
        id: String,
        isoDate: String,
        playerScore: Int,
        opponentScore: Int,
        gamesWon: (Int, Int),
        winner: String,
        points: [SamplePoint],
        elapsed: TimeInterval,
        calories: Double = 0,
        avgHR: Double = 0
    ) -> WatchGameRecord {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: isoDate) ?? Date()
        
        let events: [GameEventData] = points.enumerated().map { idx, point in
            GameEventData(
                timestamp: TimeInterval(idx * 35),
                player1Score: point.score.0,
                player2Score: point.score.1,
                scoringPlayer: point.wonBy == .player ? "You" : "Opponent",
                isServePoint: point.servedBy == .player,
                shotType: nil
            )
        }
        
        return WatchGameRecord(
            id: UUID(uuidString: id) ?? UUID(),
            date: date,
            sportType: "Pickleball",
            gameType: "Doubles",
            player1Score: playerScore,
            player2Score: opponentScore,
            player1GamesWon: gamesWon.0,
            player2GamesWon: gamesWon.1,
            elapsedTime: elapsed,
            winner: winner,
            location: "Sample Court",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: avgHR, totalCalories: calories),
            setHistory: nil
        )
    }
}
#endif
