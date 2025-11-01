//
//  GameHistory.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import Foundation
import WatchConnectivity

struct GameRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let sportType: String // "Pickleball", "Tennis", "Padel"
    let gameType: String // "Singles" or "Doubles"
    let player1Score: Int
    let player2Score: Int
    let player1GamesWon: Int
    let player2GamesWon: Int
    let elapsedTime: TimeInterval
    let matchFormatDescription: String
    let winner: String? // "You", "Opponent", or nil
    let events: [GameEventData]?
    let healthData: HealthData?
    let setHistory: [SetScore]?
    
    struct HealthData: Codable {
        let averageHeartRate: Double
        let totalCalories: Double
    }
    
    struct SetScore: Codable {
        let player1Games: Int
        let player2Games: Int
        let tiebreakScore: (Int, Int)?
        
        enum CodingKeys: String, CodingKey {
            case player1Games
            case player2Games
            case tiebreakPlayer1
            case tiebreakPlayer2
        }
        
        init(player1Games: Int, player2Games: Int, tiebreakScore: (Int, Int)? = nil) {
            self.player1Games = player1Games
            self.player2Games = player2Games
            self.tiebreakScore = tiebreakScore
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            player1Games = try container.decode(Int.self, forKey: .player1Games)
            player2Games = try container.decode(Int.self, forKey: .player2Games)
            
            if let tb1 = try container.decodeIfPresent(Int.self, forKey: .tiebreakPlayer1),
               let tb2 = try container.decodeIfPresent(Int.self, forKey: .tiebreakPlayer2) {
                tiebreakScore = (tb1, tb2)
            } else {
                tiebreakScore = nil
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(player1Games, forKey: .player1Games)
            try container.encode(player2Games, forKey: .player2Games)
            
            if let tb = tiebreakScore {
                try container.encode(tb.0, forKey: .tiebreakPlayer1)
                try container.encode(tb.1, forKey: .tiebreakPlayer2)
            }
        }
    }
    
    var scoreDisplay: String { "\(player1Score)-\(player2Score)" }
    var gameCountDisplay: String { "\(player1GamesWon)-\(player2GamesWon)" }
    
    var elapsedTimeDisplay: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: elapsedTime) ?? "00:00"
    }
    
    var sportAbbreviation: String {
        switch sportType {
        case "Pickleball": return "PB"
        case "Tennis": return "T"
        case "Padel": return "P"
        default: return "?"
        }
    }
}

struct GameEventData: Codable {
    let timestamp: TimeInterval
    let player1Score: Int
    let player2Score: Int
    let scoringPlayer: String
    let isServePoint: Bool
}

class HistoryManager: ObservableObject {
    @Published var history: [GameRecord] = []
    private let saveKey = "GameHistory"
    
    init() {
        loadHistory()
    }
    
    func addGame(_ gameState: GameState) {
        print("HistoryManager: Attempting to save game...")
        
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
        
        // Convert game events if GameState has them
        let eventData: [GameEventData]? = nil // Will be populated if GameState has gameEvents property
        
        var setHistoryData: [GameRecord.SetScore]? = nil
        if gameState.settings.matchFormatType != .single {
            var games: [GameRecord.SetScore] = []
            let winScore = gameState.settings.scoreLimit ?? 11
            
            for _ in 0..<gameState.player1GamesWon {
                games.append(GameRecord.SetScore(player1Games: winScore, player2Games: max(0, winScore - 2), tiebreakScore: nil))
            }
            for _ in 0..<gameState.player2GamesWon {
                games.append(GameRecord.SetScore(player1Games: max(0, winScore - 2), player2Games: winScore, tiebreakScore: nil))
            }
            if gameState.winner != nil {
                games.append(GameRecord.SetScore(player1Games: gameState.player1Score, player2Games: gameState.player2Score, tiebreakScore: nil))
            }
            if !games.isEmpty {
                setHistoryData = games
            }
        }

        let record = GameRecord(
            id: UUID(),
            date: Date(),
            sportType: "Pickleball",
            gameType: gameState.gameType == .singles ? "Singles" : "Doubles",
            player1Score: gameState.player1Score,
            player2Score: gameState.player2Score,
            player1GamesWon: gameState.player1GamesWon,
            player2GamesWon: gameState.player2GamesWon,
            elapsedTime: gameState.elapsedTime,
            matchFormatDescription: formatDesc,
            winner: winnerString,
            events: eventData,
            healthData: nil,
            setHistory: setHistoryData
        )

        history.insert(record, at: 0)
        saveHistory()
        sendGameToPhone(record)
        
        print("HistoryManager: Game saved! Total games in history: \(history.count)")
    }
    
    func addTennisGame(_ gameState: TennisGameState) {
        let winnerString: String? = gameState.matchWinner.map { $0 == .player1 ? "You" : "Opponent" }
        
        var formatDesc = gameState.settings.matchFormatType.rawValue
        if gameState.settings.matchFormatType == .firstTo {
            formatDesc += " \(gameState.settings.firstToGamesCount)"
        }
        
        let eventData: [GameEventData]? = gameState.gameEvents.isEmpty ? nil : gameState.gameEvents.map {
            GameEventData(
                timestamp: $0.timestamp,
                player1Score: $0.player1Score,
                player2Score: $0.player2Score,
                scoringPlayer: $0.scoringPlayer == .player1 ? "player1" : "player2",
                isServePoint: $0.isServePoint
            )
        }
        
        let setHistoryData: [GameRecord.SetScore]? = gameState.setHistory.isEmpty ? nil : gameState.setHistory.map {
            GameRecord.SetScore(
                player1Games: $0.player1Games,
                player2Games: $0.player2Games,
                tiebreakScore: $0.tiebreakScore
            )
        }
        
        let record = GameRecord(
            id: UUID(),
            date: Date(),
            sportType: "Tennis",
            gameType: gameState.gameType == .singles ? "Singles" : "Doubles",
            player1Score: gameState.player1GamesWon,
            player2Score: gameState.player2GamesWon,
            player1GamesWon: gameState.player1SetsWon,
            player2GamesWon: gameState.player2SetsWon,
            elapsedTime: gameState.elapsedTime,
            matchFormatDescription: formatDesc,
            winner: winnerString,
            events: eventData,
            healthData: nil,
            setHistory: setHistoryData
        )
        
        history.insert(record, at: 0)
        saveHistory()
        sendGameToPhone(record)
        print("✅ Tennis game saved with \(eventData?.count ?? 0) events and \(setHistoryData?.count ?? 0) sets")
    }
    
    func addPadelGame(_ gameState: PadelGameState) {
        let winnerString: String? = gameState.matchWinner.map { $0 == .player1 ? "You" : "Opponent" }
        
        var formatDesc = gameState.settings.matchFormatType.rawValue
        if gameState.settings.matchFormatType == .firstTo {
            formatDesc += " \(gameState.settings.firstToGamesCount)"
        }
        
        let eventData: [GameEventData]? = gameState.gameEvents.isEmpty ? nil : gameState.gameEvents.map {
            GameEventData(
                timestamp: $0.timestamp,
                player1Score: $0.player1Score,
                player2Score: $0.player2Score,
                scoringPlayer: $0.scoringPlayer == .player1 ? "player1" : "player2",
                isServePoint: $0.isServePoint
            )
        }
        
        let setHistoryData: [GameRecord.SetScore]? = gameState.setHistory.isEmpty ? nil : gameState.setHistory.map {
            GameRecord.SetScore(
                player1Games: $0.player1Games,
                player2Games: $0.player2Games,
                tiebreakScore: $0.tiebreakScore
            )
        }
        
        let record = GameRecord(
            id: UUID(),
            date: Date(),
            sportType: "Padel",
            gameType: "Doubles",
            player1Score: gameState.player1GamesWon,
            player2Score: gameState.player2GamesWon,
            player1GamesWon: gameState.player1SetsWon,
            player2GamesWon: gameState.player2SetsWon,
            elapsedTime: gameState.elapsedTime,
            matchFormatDescription: formatDesc,
            winner: winnerString,
            events: eventData,
            healthData: nil,
            setHistory: setHistoryData
        )
        
        history.insert(record, at: 0)
        saveHistory()
        sendGameToPhone(record)
        print("✅ Padel game saved with \(eventData?.count ?? 0) events and \(setHistoryData?.count ?? 0) sets")
    }
    
    // MARK: - Clear History Method
    func clearHistory() {
        history = []
        UserDefaults.standard.removeObject(forKey: saveKey)
        print("🗑️ History cleared")
    }
    
    // MARK: - Phone Communication
    private func sendGameToPhone(_ game: GameRecord) {
        print("📤 Watch: Sending game to iPhone...")
        
        guard WCSession.isSupported() && WCSession.default.activationState == .activated else {
            print("❌ Watch: WCSession not ready")
            return
        }
        
        let session = WCSession.default
        
        var gameData: [String: Any] = [
            "type": "newGame",
            "id": game.id.uuidString,
            "date": game.date.timeIntervalSince1970,
            "sportType": game.sportType,
            "gameType": game.gameType,
            "player1Score": game.player1Score,
            "player2Score": game.player2Score,
            "player1GamesWon": game.player1GamesWon,
            "player2GamesWon": game.player2GamesWon,
            "elapsedTime": game.elapsedTime,
            "matchFormatDescription": game.matchFormatDescription,
            "winner": game.winner ?? ""
        ]
        
        if let events = game.events, !events.isEmpty {
            gameData["events"] = events.map {
                [
                    "timestamp": $0.timestamp,
                    "player1Score": $0.player1Score,
                    "player2Score": $0.player2Score,
                    "scoringPlayer": $0.scoringPlayer,
                    "isServePoint": $0.isServePoint
                ]
            }
            print("📤 Watch: Including \(events.count) events")
        }
        
        if let setHistory = game.setHistory, !setHistory.isEmpty {
            gameData["setHistory"] = setHistory.map { set in
                var dict: [String: Any] = [
                    "player1Games": set.player1Games,
                    "player2Games": set.player2Games
                ]
                if let tb = set.tiebreakScore {
                    dict["tiebreakPlayer1"] = tb.0
                    dict["tiebreakPlayer2"] = tb.1
                }
                return dict
            }
            print("📤 Watch: Including \(setHistory.count) sets")
        }
        
        if let healthData = game.healthData {
            gameData["healthData"] = [
                "averageHeartRate": healthData.averageHeartRate,
                "totalCalories": healthData.totalCalories
            ]
        }
        
        do {
            try session.updateApplicationContext(["latestGame": gameData])
            print("✅ Watch: Sent game with events and sets via context")
        } catch {
            print("❌ Watch: Failed to send context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Persistence
    func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([GameRecord].self, from: data) {
            history = decoded
            print("📚 Loaded \(history.count) games from history")
        }
    }
}
