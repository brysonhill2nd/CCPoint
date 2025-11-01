//
//  AchievementModels.swift
//  PointiOS
//
//  Comprehensive Achievement System Models - Updated with All Achievements
//

import Foundation
import SwiftUI

// MARK: - Achievement Tier
enum AchievementTier: Int, Codable, CaseIterable {
    case regular = 1
    case bronze = 2
    case silver = 3
    case gold = 4
    case platinum = 5
    
    var points: Int {
        switch self {
        case .regular: return 10
        case .bronze: return 25
        case .silver: return 50
        case .gold: return 100
        case .platinum: return 200
        }
    }
    
    var color: Color {
        switch self {
        case .regular: return Color(hex: "#34C759")
        case .bronze: return Color(hex: "#CD7F32")
        case .silver: return Color(hex: "#C0C0C0")
        case .gold: return Color(hex: "#FFD700")
        case .platinum: return Color(hex: "#E5E4E2")
        }
    }
    
    var name: String {
        switch self {
        case .regular: return "Regular"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }
}

// MARK: - Achievement Category
enum AchievementCategory: String, CaseIterable, Codable {
    case universal = "Universal"
    case timeBased = "Time-Based"
    case performance = "Performance"
    case activity = "Activity"
    case milestones = "Milestones"
    case pickleball = "Pickleball"
    case tennis = "Tennis"
    case padel = "Padel"
}

// MARK: - Achievement Type
enum AchievementType: String, Codable {
    // Universal
    case gamesPlayed = "games_played"
    case dailyStreak = "daily_streak"
    case victories = "victories"
    case comebacks = "comebacks"
    
    // Time-Based
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    case weekendWarrior = "weekend_warrior"
    case anniversaryWin = "anniversary_win"
    case holidayHustle = "holiday_hustle"
    case newYearChampion = "new_year_champion"
    
    // Performance
    case perfectStart = "perfect_start"
    case cleanSweep = "clean_sweep"
    case marathonMatch = "marathon_match"
    case speedDemon = "speed_demon"
    case deuceMaster = "deuce_master"
    
    // Activity
    case tournamentReady = "tournament_ready"
    case crossSportAthlete = "cross_sport"
    
    // Milestones
    case centuryClub = "century_club"
    case oneYearStrong = "one_year_strong"
    case ratingClimber = "rating_climber"
    case diamondHands = "diamond_hands"
    
    // Pickleball
    case pbVictories = "pb_victories"
    case pickler = "pickler" // 11-0 wins given
    case pickled = "pickled" // 11-0 losses received
    
    // Tennis
    case tennisVictories = "tennis_victories"
    case bagelBaron = "bagel_baron" // 6-0 sets won
    case tiebreakTitan = "tiebreak_titan"
    
    // Padel
    case padelVictories = "padel_victories"
    case roscoRoyalty = "rosco_royalty" // 6-0 sets in padel
}

// MARK: - Achievement Progress
struct AchievementProgress: Codable {
    let type: AchievementType
    var currentValue: Int
    var highestTierAchieved: AchievementTier?
    var dateLastUpdated: Date
    
    init(type: AchievementType) {
        self.type = type
        self.currentValue = 0
        self.highestTierAchieved = nil
        self.dateLastUpdated = Date()
    }
}

// MARK: - Achievement Definition
struct AchievementDefinition {
    let type: AchievementType
    let category: AchievementCategory
    let name: String
    let icon: String
    let tiers: [AchievementTier: AchievementRequirement]
    
    struct AchievementRequirement {
        let value: Int
        let description: String
    }
}

// MARK: - Achievement Definitions
class AchievementDefinitions {
    static let shared = AchievementDefinitions()
    
    let definitions: [AchievementType: AchievementDefinition] = [
        // MARK: - Universal Achievements
        .gamesPlayed: AchievementDefinition(
            type: .gamesPlayed,
            category: .universal,
            name: "Games Played",
            icon: "🎮",
            tiers: [
                .regular: .init(value: 5, description: "Play 5 games"),
                .bronze: .init(value: 25, description: "Play 25 games"),
                .silver: .init(value: 50, description: "Play 50 games"),
                .gold: .init(value: 100, description: "Play 100 games"),
                .platinum: .init(value: 250, description: "Play 250 games")
            ]
        ),
        
        .dailyStreak: AchievementDefinition(
            type: .dailyStreak,
            category: .universal,
            name: "Daily Player",
            icon: "📅",
            tiers: [
                .regular: .init(value: 2, description: "2 day streak"),
                .bronze: .init(value: 3, description: "3 day streak"),
                .silver: .init(value: 7, description: "7 day streak"),
                .gold: .init(value: 14, description: "14 day streak"),
                .platinum: .init(value: 30, description: "30 day streak")
            ]
        ),
        
        .victories: AchievementDefinition(
            type: .victories,
            category: .universal,
            name: "Victory Milestone",
            icon: "🏆",
            tiers: [
                .regular: .init(value: 5, description: "Win 5 games"),
                .bronze: .init(value: 25, description: "Win 25 games"),
                .silver: .init(value: 50, description: "Win 50 games"),
                .gold: .init(value: 100, description: "Win 100 games"),
                .platinum: .init(value: 250, description: "Win 250 games")
            ]
        ),
        
        .comebacks: AchievementDefinition(
            type: .comebacks,
            category: .universal,
            name: "Comeback King",
            icon: "💪",
            tiers: [
                .regular: .init(value: 1, description: "Win after being down 5+ points"),
                .bronze: .init(value: 5, description: "5 comebacks"),
                .silver: .init(value: 10, description: "10 comebacks"),
                .gold: .init(value: 25, description: "25 comebacks"),
                .platinum: .init(value: 50, description: "50 comebacks")
            ]
        ),
        
        // MARK: - Time-Based Achievements
        .earlyBird: AchievementDefinition(
            type: .earlyBird,
            category: .timeBased,
            name: "Early Bird",
            icon: "🌅",
            tiers: [
                .silver: .init(value: 1, description: "Win a game before 7 AM")
            ]
        ),
        
        .nightOwl: AchievementDefinition(
            type: .nightOwl,
            category: .timeBased,
            name: "Night Owl",
            icon: "🦉",
            tiers: [
                .silver: .init(value: 1, description: "Win a game after 10 PM")
            ]
        ),
        
        .weekendWarrior: AchievementDefinition(
            type: .weekendWarrior,
            category: .timeBased,
            name: "Weekend Warrior",
            icon: "📅",
            tiers: [
                .bronze: .init(value: 5, description: "Play 5 games on weekends")
            ]
        ),
        
        .anniversaryWin: AchievementDefinition(
            type: .anniversaryWin,
            category: .timeBased,
            name: "Anniversary Win",
            icon: "🎂",
            tiers: [
                .gold: .init(value: 1, description: "Win on app anniversary")
            ]
        ),
        
        .holidayHustle: AchievementDefinition(
            type: .holidayHustle,
            category: .timeBased,
            name: "Holiday Hustle",
            icon: "🎄",
            tiers: [
                .silver: .init(value: 1, description: "Play on a major holiday")
            ]
        ),
        
        .newYearChampion: AchievementDefinition(
            type: .newYearChampion,
            category: .timeBased,
            name: "New Year Champion",
            icon: "🎊",
            tiers: [
                .gold: .init(value: 1, description: "Win your first game of the year")
            ]
        ),
        
        // MARK: - Performance Achievements
        .perfectStart: AchievementDefinition(
            type: .perfectStart,
            category: .performance,
            name: "Perfect Start",
            icon: "⚡",
            tiers: [
                .gold: .init(value: 1, description: "Win without losing first 3 points")
            ]
        ),
        
        .cleanSweep: AchievementDefinition(
            type: .cleanSweep,
            category: .performance,
            name: "Clean Sweep",
            icon: "🧹",
            tiers: [
                .silver: .init(value: 1, description: "Win 3 games in one day")
            ]
        ),
        
        .marathonMatch: AchievementDefinition(
            type: .marathonMatch,
            category: .performance,
            name: "Marathon Match",
            icon: "⏱️",
            tiers: [
                .gold: .init(value: 1, description: "Play a game lasting 45+ minutes")
            ]
        ),
        
        .speedDemon: AchievementDefinition(
            type: .speedDemon,
            category: .performance,
            name: "Speed Demon",
            icon: "💨",
            tiers: [
                .silver: .init(value: 1, description: "Win a game in under 10 minutes")
            ]
        ),
        
        .deuceMaster: AchievementDefinition(
            type: .deuceMaster,
            category: .performance,
            name: "Deuce Master",
            icon: "🎯",
            tiers: [
                .gold: .init(value: 1, description: "Win 5 consecutive deuce points")
            ]
        ),
        
        // MARK: - Activity Achievements
        .tournamentReady: AchievementDefinition(
            type: .tournamentReady,
            category: .activity,
            name: "Tournament Ready",
            icon: "🏆",
            tiers: [
                .gold: .init(value: 1, description: "Complete 10 games in one week")
            ]
        ),
        
        .crossSportAthlete: AchievementDefinition(
            type: .crossSportAthlete,
            category: .activity,
            name: "Cross-Sport Athlete",
            icon: "🎾",
            tiers: [
                .silver: .init(value: 3, description: "Play all three sports")
            ]
        ),
        
        // MARK: - Milestone Achievements
        .centuryClub: AchievementDefinition(
            type: .centuryClub,
            category: .milestones,
            name: "Century Club",
            icon: "💯",
            tiers: [
                .silver: .init(value: 100, description: "Score exactly 100 points total")
            ]
        ),
        
        .oneYearStrong: AchievementDefinition(
            type: .oneYearStrong,
            category: .milestones,
            name: "One Year Strong",
            icon: "📆",
            tiers: [
                .platinum: .init(value: 1, description: "Use app for full year")
            ]
        ),
        
        .ratingClimber: AchievementDefinition(
            type: .ratingClimber,
            category: .milestones,
            name: "Rating Climber",
            icon: "📈",
            tiers: [
                .gold: .init(value: 1, description: "Improve rating by 0.5+")
            ]
        ),
        
        .diamondHands: AchievementDefinition(
            type: .diamondHands,
            category: .milestones,
            name: "Diamond Hands",
            icon: "💎",
            tiers: [
                .platinum: .init(value: 100, description: "100-day streak")
            ]
        ),
        
        // MARK: - Pickleball Achievements
        .pbVictories: AchievementDefinition(
            type: .pbVictories,
            category: .pickleball,
            name: "PB Victory Milestone",
            icon: "🏆",
            tiers: [
                .regular: .init(value: 5, description: "Win 5 pickleball games"),
                .bronze: .init(value: 25, description: "Win 25 pickleball games"),
                .silver: .init(value: 50, description: "Win 50 pickleball games"),
                .gold: .init(value: 100, description: "Win 100 pickleball games"),
                .platinum: .init(value: 250, description: "Win 250 pickleball games")
            ]
        ),
        
        .pickler: AchievementDefinition(
            type: .pickler,
            category: .pickleball,
            name: "Pickler",
            icon: "🥒",
            tiers: [
                .regular: .init(value: 1, description: "Give 1 pickle (11-0)"),
                .bronze: .init(value: 3, description: "Give 3 pickles"),
                .silver: .init(value: 5, description: "Give 5 pickles"),
                .gold: .init(value: 10, description: "Give 10 pickles"),
                .platinum: .init(value: 25, description: "Give 25 pickles")
            ]
        ),
        
        .pickled: AchievementDefinition(
            type: .pickled,
            category: .pickleball,
            name: "Pickled",
            icon: "😵",
            tiers: [
                .regular: .init(value: 1, description: "Get pickled (lose 0-11)"),
                .bronze: .init(value: 3, description: "Get pickled 3 times"),
                .silver: .init(value: 5, description: "Get pickled 5 times")
            ]
        ),
        
        // MARK: - Tennis Achievements
        .tennisVictories: AchievementDefinition(
            type: .tennisVictories,
            category: .tennis,
            name: "Tennis Victory Milestone",
            icon: "🏆",
            tiers: [
                .regular: .init(value: 5, description: "Win 5 tennis games"),
                .bronze: .init(value: 25, description: "Win 25 tennis games"),
                .silver: .init(value: 50, description: "Win 50 tennis games"),
                .gold: .init(value: 100, description: "Win 100 tennis games"),
                .platinum: .init(value: 250, description: "Win 250 tennis games")
            ]
        ),
        
        .bagelBaron: AchievementDefinition(
            type: .bagelBaron,
            category: .tennis,
            name: "Bagel Baron",
            icon: "🥯",
            tiers: [
                .regular: .init(value: 1, description: "Win a 6-0 set"),
                .bronze: .init(value: 3, description: "Win 3 bagel sets"),
                .silver: .init(value: 5, description: "Win 5 bagel sets"),
                .gold: .init(value: 10, description: "Win 10 bagel sets"),
                .platinum: .init(value: 25, description: "Win 25 bagel sets")
            ]
        ),
        
        .tiebreakTitan: AchievementDefinition(
            type: .tiebreakTitan,
            category: .tennis,
            name: "Tiebreak Titan",
            icon: "🎯",
            tiers: [
                .regular: .init(value: 1, description: "Win 1 tiebreak"),
                .bronze: .init(value: 5, description: "Win 5 tiebreaks"),
                .silver: .init(value: 10, description: "Win 10 tiebreaks"),
                .gold: .init(value: 25, description: "Win 25 tiebreaks")
            ]
        ),
        
        // MARK: - Padel Achievements
        .padelVictories: AchievementDefinition(
            type: .padelVictories,
            category: .padel,
            name: "Padel Victory Milestone",
            icon: "🏆",
            tiers: [
                .regular: .init(value: 5, description: "Win 5 padel games"),
                .bronze: .init(value: 25, description: "Win 25 padel games"),
                .silver: .init(value: 50, description: "Win 50 padel games"),
                .gold: .init(value: 100, description: "Win 100 padel games"),
                .platinum: .init(value: 250, description: "Win 250 padel games")
            ]
        ),
        
        .roscoRoyalty: AchievementDefinition(
            type: .roscoRoyalty,
            category: .padel,
            name: "Rosco Royalty",
            icon: "🍩",
            tiers: [
                .regular: .init(value: 1, description: "Win a 6-0 set"),
                .bronze: .init(value: 3, description: "Win 3 roscos"),
                .silver: .init(value: 5, description: "Win 5 roscos"),
                .gold: .init(value: 10, description: "Win 10 roscos")
            ]
        )
    ]
}

// Special tier for Diamond Hands (500 points)
extension AchievementTier {
    var specialPoints: Int? {
        // Override for special achievements like Diamond Hands
        return nil
    }
}

// Helper to get points for special achievements
extension AchievementDefinition {
    func getPoints(for type: AchievementType) -> Int {
        // Special case for Diamond Hands
        if type == .diamondHands {
            return 500
        }
        // Return highest tier points for single-tier achievements
        if let tier = tiers.keys.first, tiers.count == 1 {
            return tier.points
        }
        // Otherwise return sum of all tier points
        return tiers.keys.reduce(0) { $0 + $1.points }
    }
}
