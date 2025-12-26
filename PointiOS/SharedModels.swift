// SharedModels.swift - Updated with Set History support
import Foundation

// MARK: - Sport Filter (Single Declaration)
enum SportFilter: String, CaseIterable {
    case all = "all"
    case pickleball = "pickleball"
    case tennis = "tennis"
    case padel = "padel"
}

// MARK: - Shot Types (Internal Detection Categories)
enum ShotType: String, CaseIterable, Identifiable, Codable {
    case serve = "Serve"
    case overhead = "Overhead"      // Smash/Bandeja/Víbora - we can't tell the difference
    case powerShot = "Power Shot"   // Drive/Groundstroke - hard baseline shot
    case touchShot = "Touch Shot"   // Dink/Slice/Drop - soft baseline shot
    case volley = "Volley"
    case unknown = "Unknown"

    var id: String { rawValue }

    // Get display name for specific sport
    func displayName(for sport: String, isBackhand: Bool = false) -> String {
        let handPrefix = isBackhand ? "BH " : ""

        switch sport {
        case "Pickleball":
            switch self {
            case .serve: return "Serve"
            case .overhead: return "Smash"
            case .powerShot: return "\(handPrefix)Drive"
            case .touchShot: return "\(handPrefix)Dink"
            case .volley: return "\(handPrefix)Volley"
            case .unknown: return "Unknown"
            }
        case "Tennis":
            switch self {
            case .serve: return "Serve"
            case .overhead: return "Smash"
            case .powerShot: return "\(handPrefix)Groundstroke"
            case .touchShot: return "\(handPrefix)Touch"
            case .volley: return "\(handPrefix)Volley"
            case .unknown: return "Unknown"
            }
        case "Padel":
            switch self {
            case .serve: return "Serve"
            case .overhead: return "Overhead" // Could be bajada/bandeja/víbora - can't tell
            case .powerShot: return "\(handPrefix)Drive"
            case .touchShot: return "\(handPrefix)Touch"
            case .volley: return "\(handPrefix)Volley"
            case .unknown: return "Unknown"
            }
        default:
            return "\(handPrefix)\(rawValue)"
        }
    }

    // Icon for shot type (sport-agnostic)
    var icon: String {
        switch self {
        case .serve: return "🎯"
        case .powerShot: return "💥"
        case .overhead: return "⚡️"
        case .volley: return "🛡️"
        case .touchShot: return "🪃"
        case .unknown: return "❓"
        }
    }
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
    var sport: String = "Pickleball"  // Default sport for display
}

// MARK: - Game Event Models
struct GameEventData: Codable {
    let timestamp: TimeInterval
    let player1Score: Int
    let player2Score: Int
    let scoringPlayer: String
    let isServePoint: Bool
    let shotType: String?
    let servingPlayer: String?  // "player1" or "player2" - who served this point
    let doublesServerRole: String?  // "you" or "partner" - nil for singles or opponent serving
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
    let shotType: ShotType?
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

// MARK: - Detected Shot Model (for storage)
struct StoredShot: Codable, Identifiable {
    let id: UUID
    let type: ShotType
    let intensity: Double
    let absoluteMagnitude: Double
    let timestamp: Date
    let isPointCandidate: Bool
    let gyroAngle: Double
    let swingDuration: TimeInterval
    let sport: String
    let rallyReactionTime: TimeInterval?
    let associatedWithPoint: Bool
    let isBackhand: Bool  // Detected from gyro Y-axis rotation direction

    // Display name for this shot
    var displayName: String {
        type.displayName(for: sport, isBackhand: isBackhand)
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
    let shots: [StoredShot]?  // ADDED: Shot tracking data
    
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
