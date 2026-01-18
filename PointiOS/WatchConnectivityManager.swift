// WatchConnectivityManager.swift - Fixed version
import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isWatchReachable = false
    @Published var isWatchConnected = false
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
            updateConnectionStatus(session)
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

    private func updateConnectionStatus(_ session: WCSession) {
        isWatchReachable = session.isReachable
        isWatchConnected = session.activationState == .activated &&
            session.isPaired &&
            session.isWatchAppInstalled
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

        let settings = AppData.shared.userSettings

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
            var settings = AppData.shared.userSettings.pickleballSettings

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
            AppData.shared.userSettings.pickleballSettings = settings
            AppData.shared.saveSettings()

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
                let servingPlayer = eventDict["servingPlayer"] as? String
                let doublesServerRole = eventDict["doublesServerRole"] as? String

                return GameEventData(
                    timestamp: timestamp,
                    player1Score: p1Score,
                    player2Score: p2Score,
                    scoringPlayer: scoringPlayer,
                    isServePoint: isServePoint,
                    shotType: shotType,
                    servingPlayer: servingPlayer,
                    doublesServerRole: doublesServerRole
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
                let servingPlayer = eventDict["servingPlayer"] as? String
                let doublesServerRole = eventDict["doublesServerRole"] as? String

                return GameEventData(
                    timestamp: timestamp,
                    player1Score: p1Score,
                    player2Score: p2Score,
                    scoringPlayer: scoringPlayer,
                    isServePoint: isServePoint,
                    shotType: shotType,
                    servingPlayer: servingPlayer,
                    doublesServerRole: doublesServerRole
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
            self.updateConnectionStatus(session)
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
        DispatchQueue.main.async {
            self.updateConnectionStatus(session)
        }
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
            self.updateConnectionStatus(session)
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
                setHistory: game.setHistory,
                shots: game.shots
            )
            receivedGames.insert(newGame, at: 0)
            existing.insert(newGame.id)
        }
        saveGamesToUserDefaults()
    }
}

// MARK: - Sample Game Factory
private enum SampleGameFactory {

    // MARK: - Helper Types
    private enum Participant { case player, opponent }

    private struct SamplePoint {
        let servedBy: Participant
        let wonBy: Participant
        let score: (player: Int, opponent: Int)
    }

    // MARK: - Date Helpers
    private static func hoursAgo(_ hours: Double) -> Date {
        Date().addingTimeInterval(-hours * 3600)
    }

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private static func todayAt(hour: Int, minute: Int = 0) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func yesterdayAt(hour: Int, minute: Int = 0) -> Date {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: yesterday)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Shot Generation (Realistic distributions)
    private static func generateShots(
        sport: String,
        count: Int,
        gameStartDate: Date
    ) -> [StoredShot] {
        // Realistic shot type distributions by sport
        let shotDistribution: [(ShotType, Double)]
        switch sport.lowercased() {
        case "pickleball":
            // Pickleball: lots of dinks (touch shots), kitchen play
            shotDistribution = [
                (.serve, 0.08),
                (.touchShot, 0.45),  // Dinks are most common
                (.volley, 0.25),
                (.powerShot, 0.15),
                (.overhead, 0.07)
            ]
        case "tennis":
            // Tennis: more groundstrokes (power), serves important
            shotDistribution = [
                (.serve, 0.12),
                (.powerShot, 0.48),  // Groundstrokes dominate
                (.touchShot, 0.18),
                (.volley, 0.14),
                (.overhead, 0.08)
            ]
        case "padel":
            // Padel: wall play, volleys, bandeja/vibora (overhead)
            shotDistribution = [
                (.serve, 0.10),
                (.powerShot, 0.22),
                (.touchShot, 0.28),
                (.volley, 0.25),
                (.overhead, 0.15)
            ]
        default:
            shotDistribution = [
                (.serve, 0.10),
                (.powerShot, 0.35),
                (.touchShot, 0.25),
                (.volley, 0.20),
                (.overhead, 0.10)
            ]
        }

        // Rally structure: shots come in clusters (rallies)
        var shots: [StoredShot] = []
        var currentTime: TimeInterval = 0
        var rallyLength = 0
        var inRally = false

        for i in 0..<count {
            // Start new rally periodically
            if !inRally || rallyLength == 0 {
                inRally = true
                rallyLength = Int.random(in: 3...12) // Rally length
                currentTime += Double.random(in: 8...25) // Time between points
            }

            // Pick shot type based on distribution and rally position
            let shotType: ShotType
            if rallyLength == Int.random(in: 3...12) { // First shot of rally
                shotType = .serve
            } else if rallyLength <= 2 { // End of rally - more power/winners
                shotType = Bool.random() ? .powerShot : .overhead
            } else {
                shotType = pickFromDistribution(shotDistribution)
            }

            // Backhand ratio varies by shot type
            let backhandProbability: Double
            switch shotType {
            case .serve: backhandProbability = 0.0
            case .overhead: backhandProbability = 0.05
            case .volley: backhandProbability = 0.45
            case .powerShot: backhandProbability = 0.35
            case .touchShot: backhandProbability = 0.50
            default: backhandProbability = 0.40
            }
            let isBackhand = Double.random(in: 0...1) < backhandProbability

            // Intensity varies by shot type
            let baseIntensity: Double
            switch shotType {
            case .serve: baseIntensity = Double.random(in: 0.65...0.95)
            case .powerShot: baseIntensity = Double.random(in: 0.70...0.98)
            case .overhead: baseIntensity = Double.random(in: 0.75...0.95)
            case .volley: baseIntensity = Double.random(in: 0.40...0.75)
            case .touchShot: baseIntensity = Double.random(in: 0.25...0.55)
            default: baseIntensity = Double.random(in: 0.50...0.80)
            }

            let isPointEnding = rallyLength <= 1

            shots.append(StoredShot(
                id: UUID(),
                type: shotType,
                intensity: baseIntensity,
                absoluteMagnitude: baseIntensity * 12 + Double.random(in: 2...6),
                timestamp: gameStartDate.addingTimeInterval(currentTime),
                isPointCandidate: isPointEnding,
                gyroAngle: isBackhand ? Double.random(in: -75 ... -30) : Double.random(in: 30...75),
                swingDuration: shotType == .serve ? Double.random(in: 0.25...0.40) : Double.random(in: 0.12...0.30),
                sport: sport,
                rallyReactionTime: shotType == .serve ? nil : Double.random(in: 0.4...1.5),
                associatedWithPoint: isPointEnding,
                isBackhand: isBackhand
            ))

            rallyLength -= 1
            currentTime += Double.random(in: 0.8...2.5) // Time between shots in rally

            if rallyLength <= 0 {
                inRally = false
            }
        }

        return shots
    }

    private static func pickFromDistribution(_ distribution: [(ShotType, Double)]) -> ShotType {
        let total = distribution.reduce(0) { $0 + $1.1 }
        var random = Double.random(in: 0..<total)
        for (type, weight) in distribution {
            random -= weight
            if random <= 0 { return type }
        }
        return distribution.first?.0 ?? .powerShot
    }

    // MARK: - Event Generation for Pickleball
    private static func generatePickleballEvents(
        finalScore1: Int,
        finalScore2: Int,
        duration: TimeInterval,
        isDoubles: Bool = false
    ) -> [GameEventData] {
        var events: [GameEventData] = []
        var score1 = 0, score2 = 0
        var timestamp: TimeInterval = 0
        let avgPointTime = duration / Double(finalScore1 + finalScore2)

        // Track serving - in pickleball only serving team can score
        var servingPlayer = "player1"
        var doublesRole: String? = isDoubles ? "you" : nil

        while score1 < finalScore1 || score2 < finalScore2 {
            let remaining1 = finalScore1 - score1
            let remaining2 = finalScore2 - score2
            let player1Wins = Double.random(in: 0...1) < Double(remaining1) / Double(remaining1 + remaining2)

            // In pickleball, only serving team scores
            var scored = false
            var scorer = ""
            if servingPlayer == "player1" && player1Wins && score1 < finalScore1 {
                score1 += 1
                scored = true
                scorer = "player1"
            } else if servingPlayer == "player2" && !player1Wins && score2 < finalScore2 {
                score2 += 1
                scored = true
                scorer = "player2"
            } else {
                // Side out - switch server, don't create event for side out itself
                servingPlayer = servingPlayer == "player1" ? "player2" : "player1"
                doublesRole = servingPlayer == "player1" && isDoubles ? ["you", "partner"].randomElement() : nil
                continue
            }

            // Only create event when score changes
            if scored {
                events.append(GameEventData(
                    timestamp: timestamp,
                    player1Score: score1,
                    player2Score: score2,
                    scoringPlayer: scorer,
                    isServePoint: false,
                    shotType: nil,
                    servingPlayer: servingPlayer,
                    doublesServerRole: doublesRole
                ))
                timestamp += avgPointTime * Double.random(in: 0.7...1.4)
            }
        }

        return events
    }

    private static func generatePickleballEvents(
        scoringSequence: [Participant],
        duration: TimeInterval,
        isDoubles: Bool = false
    ) -> [GameEventData] {
        var events: [GameEventData] = []
        var score1 = 0
        var score2 = 0
        var timestamp: TimeInterval = 0
        let avgPointTime = duration / Double(max(scoringSequence.count, 1))

        // Track serving - in pickleball only serving team can score
        var servingPlayer = "player1"
        var doublesRole: String? = isDoubles ? "you" : nil

        for scorer in scoringSequence {
            let scoringPlayer = scorer == .player ? "player1" : "player2"

            // In Pickleball, only serving team scores
            // If scorer doesn't match server, there was a side out first
            if scoringPlayer != servingPlayer {
                servingPlayer = scoringPlayer
                doublesRole = servingPlayer == "player1" && isDoubles ? ["you", "partner"].randomElement() : nil
            }

            if scorer == .player {
                score1 += 1
            } else {
                score2 += 1
            }

            events.append(GameEventData(
                timestamp: timestamp,
                player1Score: score1,
                player2Score: score2,
                scoringPlayer: scoringPlayer,
                isServePoint: false,
                shotType: nil,
                servingPlayer: servingPlayer,
                doublesServerRole: doublesRole
            ))

            timestamp += avgPointTime * Double.random(in: 0.7...1.3)
        }

        return events
    }

    // MARK: - Build All Samples
    static func buildSamples() -> [WatchGameRecord] {
        [
            // Today's games - showcase variety and impressive stats
            pickleballComebackWinToday(),
            pickleballLeadBlownLossYesterday(),
            pickleballBackAndForthWinTwoDaysAgo(),
            pickleballCloseWinToday(),
            pickleballDoublesLossToday(),
            pickleballDominantWinToday(),
            tennisSinglesWinToday(),

            // Yesterday's games
            padelDoublesYesterday(),
            pickleballSinglesYesterday(),
            tennisThreeSetterYesterday(),

            // Earlier this week
            pickleballDoublesThreeDaysAgo(),
            padelLessonFourDaysAgo(),
            pickleballExtendedGameFiveDaysAgo()
        ]
    }

    // MARK: - Tennis Event Generation (Realistic 0-15-30-40 scoring)
    /// Generates realistic tennis point-by-point events with proper scoring
    private static func generateTennisEvents(
        sets: [WatchSetScore],
        duration: TimeInterval,
        isDoubles: Bool = false
    ) -> [GameEventData] {
        var events: [GameEventData] = []
        var timestamp: TimeInterval = 0

        // Tennis point values
        let pointValues = [0, 15, 30, 40]

        var totalGames = sets.reduce(0) { $0 + $1.player1Games + $1.player2Games }
        let avgGameTime = duration / Double(max(totalGames, 1))

        var servingPlayer = "player1" // Alternates each game
        var gamesPlayed = 0

        for (setIndex, set) in sets.enumerated() {
            var player1GamesInSet = 0
            var player2GamesInSet = 0

            // Generate games until set is complete
            while player1GamesInSet < set.player1Games || player2GamesInSet < set.player2Games {
                // Determine who wins this game based on final score
                let player1NeedsGames = set.player1Games - player1GamesInSet
                let player2NeedsGames = set.player2Games - player2GamesInSet
                let player1WinsGame = Double.random(in: 0...1) < Double(player1NeedsGames) / Double(player1NeedsGames + player2NeedsGames)

                // Generate points for this game
                var p1Points = 0 // Index into pointValues
                var p2Points = 0
                var gameOver = false
                var pointsInGame = 0

                while !gameOver {
                    pointsInGame += 1

                    // Bias point winner toward game winner
                    let p1WinsPoint: Bool
                    if player1WinsGame {
                        p1WinsPoint = Double.random(in: 0...1) < 0.58 // Slight edge
                    } else {
                        p1WinsPoint = Double.random(in: 0...1) < 0.42
                    }

                    // Update point scores
                    if p1WinsPoint {
                        p1Points += 1
                    } else {
                        p2Points += 1
                    }

                    // Determine display scores
                    let p1Display: Int
                    let p2Display: Int

                    if p1Points <= 3 && p2Points <= 3 {
                        p1Display = pointValues[p1Points]
                        p2Display = pointValues[p2Points]
                    } else if p1Points >= 3 && p2Points >= 3 {
                        // Deuce/Advantage
                        if p1Points == p2Points {
                            p1Display = 40
                            p2Display = 40 // Deuce
                        } else if p1Points > p2Points {
                            p1Display = 50 // AD (we'll display as "AD")
                            p2Display = 40
                        } else {
                            p1Display = 40
                            p2Display = 50 // AD
                        }
                    } else {
                        p1Display = p1Points >= 4 ? 50 : pointValues[min(p1Points, 3)]
                        p2Display = p2Points >= 4 ? 50 : pointValues[min(p2Points, 3)]
                    }

                    // Check if game is over
                    if p1Points >= 4 && p1Points - p2Points >= 2 {
                        gameOver = true
                        player1GamesInSet += 1
                    } else if p2Points >= 4 && p2Points - p1Points >= 2 {
                        gameOver = true
                        player2GamesInSet += 1
                    }

                    let doublesRole: String? = isDoubles && servingPlayer == "player1" ? ["you", "partner"].randomElement() : nil

                    events.append(GameEventData(
                        timestamp: timestamp,
                        player1Score: p1Display,
                        player2Score: p2Display,
                        scoringPlayer: p1WinsPoint ? "player1" : "player2",
                        isServePoint: false,
                        shotType: nil,
                        servingPlayer: servingPlayer,
                        doublesServerRole: doublesRole
                    ))

                    timestamp += Double.random(in: 15...45) // Time per point
                }

                gamesPlayed += 1
                // Server alternates each game
                servingPlayer = servingPlayer == "player1" ? "player2" : "player1"
                timestamp += Double.random(in: 60...90) // Changeover time
            }
        }

        return events
    }

    // MARK: - Enhanced Event Generation with Highlights
    /// Generates detailed point-by-point events with momentum shifts and key moments
    private static func generateDetailedEvents(
        finalScore1: Int,
        finalScore2: Int,
        duration: TimeInterval,
        sport: String,
        isDoubles: Bool = false
    ) -> [GameEventData] {
        var events: [GameEventData] = []
        var score1 = 0, score2 = 0
        var timestamp: TimeInterval = 0
        let avgPointTime = duration / Double(finalScore1 + finalScore2 + 5) // Account for side outs

        // Track serving
        var servingPlayer = "player1"
        var consecutivePoints = 0
        var lastScorer = ""

        while score1 < finalScore1 || score2 < finalScore2 {
            let remaining1 = finalScore1 - score1
            let remaining2 = finalScore2 - score2

            // Bias toward player1 winning based on remaining points
            let player1WinsPoint = Double.random(in: 0...1) < Double(remaining1) / Double(remaining1 + remaining2 + 1)

            // Determine if server scores (different rules for different sports)
            if sport == "Pickleball" {
                // Pickleball: only serving team can score
                if servingPlayer == "player1" && player1WinsPoint && score1 < finalScore1 {
                    score1 += 1
                } else if servingPlayer == "player2" && !player1WinsPoint && score2 < finalScore2 {
                    score2 += 1
                } else {
                    // Side out
                    servingPlayer = servingPlayer == "player1" ? "player2" : "player1"
                    continue // No score on side out
                }
            } else {
                // Tennis/Padel: anyone can score
                if player1WinsPoint && score1 < finalScore1 {
                    score1 += 1
                } else if !player1WinsPoint && score2 < finalScore2 {
                    score2 += 1
                }
            }

            let scorer = player1WinsPoint ? "player1" : "player2"

            // Track consecutive points (momentum)
            if scorer == lastScorer {
                consecutivePoints += 1
            } else {
                consecutivePoints = 1
                lastScorer = scorer
            }

            let doublesRole: String? = isDoubles && servingPlayer == "player1"
                ? ["you", "partner"].randomElement()
                : nil

            events.append(GameEventData(
                timestamp: timestamp,
                player1Score: score1,
                player2Score: score2,
                scoringPlayer: scorer,
                isServePoint: false,
                shotType: nil,
                servingPlayer: servingPlayer,
                doublesServerRole: doublesRole
            ))

            // Vary point duration
            let pointVariation = consecutivePoints >= 3 ? 0.6 : 1.2 // Quick points on runs
            timestamp += avgPointTime * Double.random(in: 0.5...1.5) * pointVariation

            // Alternate server in Tennis/Padel after each game (simplified)
            if sport != "Pickleball" && (score1 + score2) % 4 == 0 {
                servingPlayer = servingPlayer == "player1" ? "player2" : "player1"
            }
        }

        return events
    }

    // MARK: - Today's Games

    /// Pickleball Singles - Close 11-9 win, just finished
    private static func pickleballCloseWinToday() -> WatchGameRecord {
        let gameDate = hoursAgo(0.25) // 15 minutes ago
        let events = generatePickleballEvents(finalScore1: 11, finalScore2: 9, duration: 1380)
        let shots = generateShots(sport: "Pickleball", count: 67, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Singles",
            player1Score: 11,
            player2Score: 9,
            player1GamesWon: 1,
            player2GamesWon: 0,
            elapsedTime: 1380, // 23 minutes
            winner: "You",
            location: "Sunset Pickleball Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 142, totalCalories: 187),
            setHistory: nil,
            shots: shots
        )
    }

    /// Pickleball Singles - Comeback 11-9 win after trailing 0-7
    private static func pickleballComebackWinToday() -> WatchGameRecord {
        let gameDate = hoursAgo(0.6)
        let sequence = Array(repeating: Participant.opponent, count: 7)
            + Array(repeating: Participant.player, count: 6)
            + [Participant.opponent]
            + Array(repeating: Participant.player, count: 5)
            + [Participant.opponent]
        let events = generatePickleballEvents(scoringSequence: sequence, duration: 1500)
        let shots = generateShots(sport: "Pickleball", count: 72, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000011") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Singles",
            player1Score: 11,
            player2Score: 9,
            player1GamesWon: 1,
            player2GamesWon: 0,
            elapsedTime: 1500,
            winner: "You",
            location: "Sunset Pickleball Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 149, totalCalories: 201),
            setHistory: nil,
            shots: shots
        )
    }

    /// Pickleball Doubles - Loss 7-11
    private static func pickleballDoublesLossToday() -> WatchGameRecord {
        let gameDate = hoursAgo(1.5)
        let events = generatePickleballEvents(finalScore1: 7, finalScore2: 11, duration: 1695, isDoubles: true)
        let shots = generateShots(sport: "Pickleball", count: 58, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Doubles",
            player1Score: 7,
            player2Score: 11,
            player1GamesWon: 0,
            player2GamesWon: 1,
            elapsedTime: 1695, // 28 minutes
            winner: "Opponent",
            location: "Sunset Pickleball Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 128, totalCalories: 156),
            setHistory: nil,
            shots: shots
        )
    }

    /// Pickleball Singles - Led big, lost 9-11
    private static func pickleballLeadBlownLossYesterday() -> WatchGameRecord {
        let gameDate = yesterdayAt(hour: 18, minute: 20)
        let sequence = Array(repeating: Participant.player, count: 8)
            + Array(repeating: Participant.opponent, count: 2)
            + Array(repeating: Participant.opponent, count: 5)
            + [Participant.player]
            + Array(repeating: Participant.opponent, count: 4)
        let events = generatePickleballEvents(scoringSequence: sequence, duration: 1620)
        let shots = generateShots(sport: "Pickleball", count: 70, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000012") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Singles",
            player1Score: 9,
            player2Score: 11,
            player1GamesWon: 0,
            player2GamesWon: 1,
            elapsedTime: 1620,
            winner: "Opponent",
            location: "Sunset Pickleball Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 151, totalCalories: 214),
            setHistory: nil,
            shots: shots
        )
    }

    /// Pickleball Singles - Back-and-forth 11-9 win
    private static func pickleballBackAndForthWinTwoDaysAgo() -> WatchGameRecord {
        let gameDate = daysAgo(2)
        var sequence: [Participant] = []
        for i in 0..<18 {
            sequence.append(i % 2 == 0 ? .player : .opponent)
        }
        sequence.append(contentsOf: [.player, .player])
        let events = generatePickleballEvents(scoringSequence: sequence, duration: 1740)
        let shots = generateShots(sport: "Pickleball", count: 78, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000013") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Singles",
            player1Score: 11,
            player2Score: 9,
            player1GamesWon: 1,
            player2GamesWon: 0,
            elapsedTime: 1740,
            winner: "You",
            location: "Sunset Pickleball Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 146, totalCalories: 198),
            setHistory: nil,
            shots: shots
        )
    }

    /// Pickleball Singles - Dominant 11-3 win
    private static func pickleballDominantWinToday() -> WatchGameRecord {
        let gameDate = hoursAgo(2.5)
        let events = generatePickleballEvents(finalScore1: 11, finalScore2: 3, duration: 933)
        let shots = generateShots(sport: "Pickleball", count: 42, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Singles",
            player1Score: 11,
            player2Score: 3,
            player1GamesWon: 1,
            player2GamesWon: 0,
            elapsedTime: 933, // 15:33
            winner: "You",
            location: "Sunset Pickleball Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 135, totalCalories: 112),
            setHistory: nil,
            shots: shots
        )
    }

    /// Tennis Singles - 6-4 set win with realistic point-by-point
    private static func tennisSinglesWinToday() -> WatchGameRecord {
        let gameDate = hoursAgo(5)
        let sets = [WatchSetScore(player1Games: 6, player2Games: 4, tiebreakScore: nil)]
        let duration: TimeInterval = 3138 // 52 minutes
        let shots = generateShots(sport: "Tennis", count: 124, gameStartDate: gameDate)
        let events = generateTennisEvents(sets: sets, duration: duration, isDoubles: false)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004") ?? UUID(),
            date: gameDate,
            sportType: "Tennis",
            gameType: "Singles",
            player1Score: 0,
            player2Score: 0,
            player1GamesWon: 6,
            player2GamesWon: 4,
            elapsedTime: duration,
            winner: "You",
            location: "Marina Tennis Club",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 156, totalCalories: 412),
            setHistory: sets,
            shots: shots
        )
    }

    // MARK: - Yesterday's Games

    /// Padel Doubles - Won tiebreak 7-6 (7-5) with realistic point-by-point
    private static func padelDoublesYesterday() -> WatchGameRecord {
        let gameDate = yesterdayAt(hour: 18, minute: 30)
        let sets = [WatchSetScore(player1Games: 7, player2Games: 6, tiebreakScore: (7, 5))]
        let duration: TimeInterval = 4125 // 68:45
        let shots = generateShots(sport: "Padel", count: 156, gameStartDate: gameDate)
        let events = generateTennisEvents(sets: sets, duration: duration, isDoubles: true)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005") ?? UUID(),
            date: gameDate,
            sportType: "Padel",
            gameType: "Doubles",
            player1Score: 0,
            player2Score: 0,
            player1GamesWon: 7,
            player2GamesWon: 6,
            elapsedTime: duration,
            winner: "You",
            location: "Bay Area Padel Club",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 148, totalCalories: 523),
            setHistory: sets,
            shots: shots
        )
    }

    /// Pickleball Singles - Quick loss 5-11
    private static func pickleballSinglesYesterday() -> WatchGameRecord {
        let gameDate = yesterdayAt(hour: 15, minute: 0)
        let events = generatePickleballEvents(finalScore1: 5, finalScore2: 11, duration: 1102)
        let shots = generateShots(sport: "Pickleball", count: 48, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000006") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Singles",
            player1Score: 5,
            player2Score: 11,
            player1GamesWon: 0,
            player2GamesWon: 1,
            elapsedTime: 1102, // 18:22
            winner: "Opponent",
            location: "Community Center Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 138, totalCalories: 134),
            setHistory: nil,
            shots: shots
        )
    }

    /// Tennis Singles - Three-setter win (4-6, 6-2, 6-3) with full point-by-point
    private static func tennisThreeSetterYesterday() -> WatchGameRecord {
        let gameDate = yesterdayAt(hour: 10, minute: 0)
        let sets = [
            WatchSetScore(player1Games: 4, player2Games: 6, tiebreakScore: nil),
            WatchSetScore(player1Games: 6, player2Games: 2, tiebreakScore: nil),
            WatchSetScore(player1Games: 6, player2Games: 3, tiebreakScore: nil)
        ]
        let duration: TimeInterval = 5700 // 1h 35m
        let shots = generateShots(sport: "Tennis", count: 245, gameStartDate: gameDate)
        let events = generateTennisEvents(sets: sets, duration: duration, isDoubles: false)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000007") ?? UUID(),
            date: gameDate,
            sportType: "Tennis",
            gameType: "Singles",
            player1Score: 0,
            player2Score: 0,
            player1GamesWon: 2,
            player2GamesWon: 1,
            elapsedTime: duration,
            winner: "You",
            location: "Golden Gate Park Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 162, totalCalories: 687),
            setHistory: sets,
            shots: shots
        )
    }

    // MARK: - Earlier This Week

    /// Pickleball Doubles - 3 days ago, win 11-8
    private static func pickleballDoublesThreeDaysAgo() -> WatchGameRecord {
        let gameDate = daysAgo(3).addingTimeInterval(14 * 3600) // 2 PM
        let events = generatePickleballEvents(finalScore1: 11, finalScore2: 8, duration: 1305, isDoubles: true)
        let shots = generateShots(sport: "Pickleball", count: 62, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000008") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Doubles",
            player1Score: 11,
            player2Score: 8,
            player1GamesWon: 1,
            player2GamesWon: 0,
            elapsedTime: 1305, // 21:45
            winner: "You",
            location: "Sunset Pickleball Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 145, totalCalories: 178),
            setHistory: nil,
            shots: shots
        )
    }

    /// Padel Lesson - 4 days ago, 6-2 set with realistic point-by-point
    private static func padelLessonFourDaysAgo() -> WatchGameRecord {
        let gameDate = daysAgo(4).addingTimeInterval(11 * 3600) // 11 AM
        let sets = [WatchSetScore(player1Games: 6, player2Games: 2, tiebreakScore: nil)]
        let duration: TimeInterval = 2700 // 45 minutes
        let shots = generateShots(sport: "Padel", count: 98, gameStartDate: gameDate)
        let events = generateTennisEvents(sets: sets, duration: duration, isDoubles: true)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000009") ?? UUID(),
            date: gameDate,
            sportType: "Padel",
            gameType: "Doubles",
            player1Score: 0,
            player2Score: 0,
            player1GamesWon: 6,
            player2GamesWon: 2,
            elapsedTime: duration,
            winner: "You",
            location: "Bay Area Padel Club",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 132, totalCalories: 298),
            setHistory: sets,
            shots: shots
        )
    }

    /// Pickleball Singles - 5 days ago, extended game 13-11
    private static func pickleballExtendedGameFiveDaysAgo() -> WatchGameRecord {
        let gameDate = daysAgo(5).addingTimeInterval(9 * 3600) // 9 AM
        let events = generatePickleballEvents(finalScore1: 13, finalScore2: 11, duration: 2128)
        let shots = generateShots(sport: "Pickleball", count: 89, gameStartDate: gameDate)

        return WatchGameRecord(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000010") ?? UUID(),
            date: gameDate,
            sportType: "Pickleball",
            gameType: "Singles",
            player1Score: 13,
            player2Score: 11,
            player1GamesWon: 1,
            player2GamesWon: 0,
            elapsedTime: 2128, // 35:28
            winner: "You",
            location: "Community Center Courts",
            events: events,
            healthData: WatchGameHealthData(averageHeartRate: 151, totalCalories: 267),
            setHistory: nil,
            shots: shots
        )
    }
}
#endif
