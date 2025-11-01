// SharedModels.swift - Updated with Set History support
import Foundation

// MARK: - Sport Filter (Single Declaration)
enum SportFilter: String, CaseIterable {
    case all = "all"
    case pickleball = "pickleball"
    case tennis = "tennis"
    case padel = "padel"
}

// MARK: - Session Summary
struct SessionSummary {
    let date: Date
    let location: String
    let gamesPlayed: Int
    let gamesWon: Int
    let totalTime: TimeInterval
    var calories: Double
    var avgHeartRate: Double
}

// MARK: - Game Event Models
struct GameEventData: Codable {
    let timestamp: TimeInterval
    let player1Score: Int
    let player2Score: Int
    let scoringPlayer: String
    let isServePoint: Bool
}

// MARK: - Player enum for iOS
enum Player {
    case player1
    case player2
}

// MARK: - Game Event for iOS
struct GameEvent {
    let timestamp: TimeInterval
    let player1Score: Int
    let player2Score: Int
    let scoringPlayer: Player
    let isServePoint: Bool
}

// MARK: - Health Data Structure
struct WatchGameHealthData: Codable {
    let averageHeartRate: Double
    let totalCalories: Double
}

// MARK: - Set Score for Tennis/Padel
struct WatchSetScore: Codable {
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

// MARK: - Game Record Model
struct WatchGameRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let sportType: String
    let gameType: String
    let player1Score: Int
    let player2Score: Int
    let player1GamesWon: Int
    let player2GamesWon: Int
    let elapsedTime: TimeInterval
    let winner: String?
    let location: String?
    let events: [GameEventData]?
    let healthData: WatchGameHealthData?
    let setHistory: [WatchSetScore]?  // ADDED: Set history for Tennis/Padel
    
    var scoreDisplay: String {
        "\(player1Score) - \(player2Score)"
    }
    
    var elapsedTimeDisplay: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: elapsedTime) ?? "00:00"
    }
    
    var sportEmoji: String {
        switch sportType {
        case "Pickleball": return "🥒"
        case "Tennis": return "🎾"
        case "Padel": return "🏓"
        default: return "🏸"
        }
    }
}
