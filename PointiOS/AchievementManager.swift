//
//  AchievementManager.swift
//  PointiOS
//
//  Achievement Manager - Updated with Comprehensive Achievement Checking
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    @Published var userProgress: [AchievementType: AchievementProgress] = [:]
    @Published var totalPoints: Int = 0
    @Published var newlyUnlockedAchievements: [(AchievementType, AchievementTier)] = []
    
    private let userDefaults = UserDefaults.standard
    private let progressKey = "achievementProgress"
    private let pointsKey = "achievementPoints"
    private let appStartDateKey = "appFirstLaunchDate"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadProgress()
        setupAppStartDate()
        setupAutoSync()
    }
    
    private func setupAppStartDate() {
        if userDefaults.object(forKey: appStartDateKey) == nil {
            userDefaults.set(Date(), forKey: appStartDateKey)
        }
    }
    
    // MARK: - Progress Management
    func checkAchievements(for games: [WatchGameRecord], user: PointUser? = nil) {
        newlyUnlockedAchievements.removeAll()
        
        // Universal achievements
        checkUniversalAchievements(games)
        
        // Time-based achievements
        checkTimeBasedAchievements(games)
        
        // Performance achievements
        checkPerformanceAchievements(games)
        
        // Activity achievements
        checkActivityAchievements(games)
        
        // Milestone achievements
        checkMilestoneAchievements(games)
        
        // Sport-specific achievements
        checkPickleballAchievements(games.filter { $0.sportType == "Pickleball" })
        checkTennisAchievements(games.filter { $0.sportType == "Tennis" })
        checkPadelAchievements(games.filter { $0.sportType == "Padel" })
        
        // Calculate total points
        calculateTotalPoints()
        
        // Save progress
        saveProgress()
    }
    
    // MARK: - Universal Achievements
    private func checkUniversalAchievements(_ games: [WatchGameRecord]) {
        // Games Played
        updateProgress(for: .gamesPlayed, value: games.count)
        
        // Victories
        let wins = games.filter { $0.winner == "You" }.count
        updateProgress(for: .victories, value: wins)
        
        // Daily Streak
        let streak = calculateDailyStreak(from: games)
        updateProgress(for: .dailyStreak, value: streak)
        
        // Comebacks (requires event data)
        let comebacks = countComebacks(in: games)
        updateProgress(for: .comebacks, value: comebacks)
    }
    
    // MARK: - Time-Based Achievements
    private func checkTimeBasedAchievements(_ games: [WatchGameRecord]) {
        let calendar = Calendar.current
        
        // Early Bird - Win before 7 AM
        let earlyWins = games.filter { game in
            game.winner == "You" && calendar.component(.hour, from: game.date) < 7
        }.count
        if earlyWins > 0 {
            updateProgress(for: .earlyBird, value: 1)
        }
        
        // Night Owl - Win after 10 PM
        let lateWins = games.filter { game in
            game.winner == "You" && calendar.component(.hour, from: game.date) >= 22
        }.count
        if lateWins > 0 {
            updateProgress(for: .nightOwl, value: 1)
        }
        
        // Weekend Warrior - Games on weekends
        let weekendGames = games.filter { game in
            let weekday = calendar.component(.weekday, from: game.date)
            return weekday == 1 || weekday == 7 // Sunday or Saturday
        }.count
        updateProgress(for: .weekendWarrior, value: weekendGames)
        
        // Anniversary Win - Win on app anniversary (only check today's games)
        if let appStartDate = userDefaults.object(forKey: appStartDateKey) as? Date {
            let today = Date()
            let todayMonth = calendar.component(.month, from: today)
            let todayDay = calendar.component(.day, from: today)
            let appMonth = calendar.component(.month, from: appStartDate)
            let appDay = calendar.component(.day, from: appStartDate)
            
            // Check if today is the anniversary
            if todayMonth == appMonth && todayDay == appDay {
                // Check if any game played TODAY is a win
                let todayStart = calendar.startOfDay(for: today)
                let todayWins = games.filter { game in
                    game.winner == "You" &&
                    calendar.startOfDay(for: game.date) == todayStart
                }.count
                
                if todayWins > 0 {
                    updateProgress(for: .anniversaryWin, value: 1)
                }
            }
        }
        
        // Holiday Hustle - Play on major holidays
        let holidayGames = games.filter { game in
            isHoliday(date: game.date)
        }.count
        if holidayGames > 0 {
            updateProgress(for: .holidayHustle, value: 1)
        }
        
        // New Year Champion - Win first game of the current year
        let currentYear = calendar.component(.year, from: Date())
        let currentYearGames = games.filter { game in
            calendar.component(.year, from: game.date) == currentYear
        }.sorted { $0.date < $1.date }
        
        // Check if the first game of the current year is a win
        if let firstGameOfYear = currentYearGames.first,
           firstGameOfYear.winner == "You" {
            updateProgress(for: .newYearChampion, value: 1)
        }
    }
    
    // MARK: - Performance Achievements
    private func checkPerformanceAchievements(_ games: [WatchGameRecord]) {
        // Perfect Start - Win without losing first 3 points
        let perfectStarts = games.filter { game in
            guard game.winner == "You", let events = game.events else { return false }
            
            // Check first 3 points scored
            var pointsScored = 0
            for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
                if event.player2Score > 0 && pointsScored < 3 {
                    return false // Opponent scored in first 3 points
                }
                pointsScored = event.player1Score + event.player2Score
                if pointsScored >= 3 {
                    break
                }
            }
            return true
        }.count
        if perfectStarts > 0 {
            updateProgress(for: .perfectStart, value: 1)
        }
        
        // Clean Sweep - Win 3 games in one day
        let calendar = Calendar.current
        let gamesByDay = Dictionary(grouping: games.filter { $0.winner == "You" }) { game in
            calendar.startOfDay(for: game.date)
        }
        
        let cleanSweepDays = gamesByDay.values.filter { $0.count >= 3 }.count
        if cleanSweepDays > 0 {
            updateProgress(for: .cleanSweep, value: 1)
        }
        
        // Marathon Match - Game lasting 45+ minutes
        let marathonMatches = games.filter { $0.elapsedTime >= 2700 }.count // 45 minutes = 2700 seconds
        if marathonMatches > 0 {
            updateProgress(for: .marathonMatch, value: 1)
        }
        
        // Speed Demon - Win in under 10 minutes
        let speedWins = games.filter { game in
            game.winner == "You" && game.elapsedTime < 600 // 10 minutes = 600 seconds
        }.count
        if speedWins > 0 {
            updateProgress(for: .speedDemon, value: 1)
        }
        
        // Deuce Master - Win 5 consecutive deuce points (tennis specific, needs event data)
        // This would require tracking deuce situations in tennis games
        // For now, leaving as placeholder
    }
    
    // MARK: - Activity Achievements
    private func checkActivityAchievements(_ games: [WatchGameRecord]) {
        // Tournament Ready - 10 games in one week
        let calendar = Calendar.current
        let gamesByWeek = Dictionary(grouping: games) { game in
            calendar.dateInterval(of: .weekOfYear, for: game.date)?.start ?? game.date
        }
        
        let tournamentReadyWeeks = gamesByWeek.values.filter { $0.count >= 10 }.count
        if tournamentReadyWeeks > 0 {
            updateProgress(for: .tournamentReady, value: 1)
        }
        
        // Cross-Sport Athlete - Play all three sports
        let sports = Set(games.map { $0.sportType })
        if sports.count >= 3 {
            updateProgress(for: .crossSportAthlete, value: 3)
        }
        
        // Home Court Advantage - Win 10 games at same location
        // REMOVED: Location tracking not implemented
        
        // Road Warrior - Play at 5 different venues
        // REMOVED: Location tracking not implemented
        
        // International Player - Play in different country
        // REMOVED: Location tracking not implemented
    }
    
    // MARK: - Milestone Achievements
    private func checkMilestoneAchievements(_ games: [WatchGameRecord]) {
        // Century Club - Score exactly 100 points total
        let totalPointsScored = games.reduce(0) { $0 + $1.player1Score }
        updateProgress(for: .centuryClub, value: totalPointsScored)
        
        // One Year Strong - Use app for full year
        if let appStartDate = userDefaults.object(forKey: appStartDateKey) as? Date {
            let daysSinceStart = Calendar.current.dateComponents([.day], from: appStartDate, to: Date()).day ?? 0
            if daysSinceStart >= 365 {
                updateProgress(for: .oneYearStrong, value: 1)
            }
        }
        
        // Rating Climber - Improve rating by 0.5+
        // This would require rating tracking functionality
        // Placeholder for now
        
        // Diamond Hands - 100-day streak
        let streak = calculateDailyStreak(from: games)
        if streak >= 100 {
            updateProgress(for: .diamondHands, value: 100)
        }
    }
    
    // MARK: - Pickleball Achievements
    private func checkPickleballAchievements(_ games: [WatchGameRecord]) {
        // PB Victories
        let wins = games.filter { $0.winner == "You" }.count
        updateProgress(for: .pbVictories, value: wins)
        
        // Pickler - Count pickles (11-0 wins)
        let pickles = games.filter {
            $0.winner == "You" && $0.player1Score == 11 && $0.player2Score == 0
        }.count
        updateProgress(for: .pickler, value: pickles)
        
        // Pickled - Count times got pickled (0-11 losses)
        let pickled = games.filter {
            $0.winner == "Opponent" && $0.player1Score == 0 && $0.player2Score == 11
        }.count
        updateProgress(for: .pickled, value: pickled)
    }
    
    // MARK: - Tennis Achievements
    private func checkTennisAchievements(_ games: [WatchGameRecord]) {
        // Tennis Victories
        let wins = games.filter { $0.winner == "You" }.count
        updateProgress(for: .tennisVictories, value: wins)
        
        // Bagel Baron - 6-0 sets
        // This would require set score tracking
        // For now, using game score as proxy
        let bagels = games.filter {
            $0.winner == "You" && $0.player1Score == 6 && $0.player2Score == 0
        }.count
        updateProgress(for: .bagelBaron, value: bagels)
        
        // Tiebreak Titan
        // Would require tiebreak detection in tennis games
        // Placeholder for now
    }
    
    // MARK: - Padel Achievements
    private func checkPadelAchievements(_ games: [WatchGameRecord]) {
        // Padel Victories
        let wins = games.filter { $0.winner == "You" }.count
        updateProgress(for: .padelVictories, value: wins)
        
        // Rosco Royalty - 6-0 sets in padel
        let roscos = games.filter {
            $0.winner == "You" && $0.player1Score == 6 && $0.player2Score == 0
        }.count
        updateProgress(for: .roscoRoyalty, value: roscos)
    }
    
    // MARK: - Helper Methods
    private func updateProgress(for type: AchievementType, value: Int) {
        var progress = userProgress[type] ?? AchievementProgress(type: type)
        progress.currentValue = value
        progress.dateLastUpdated = Date()
        
        // Check for tier achievements
        if let definition = AchievementDefinitions.shared.definitions[type] {
            for (tier, requirement) in definition.tiers.sorted(by: { $0.key.rawValue > $1.key.rawValue }) {
                if value >= requirement.value {
                    if progress.highestTierAchieved == nil || tier.rawValue > progress.highestTierAchieved!.rawValue {
                        progress.highestTierAchieved = tier
                        newlyUnlockedAchievements.append((type, tier))
                    }
                    break
                }
            }
        }
        
        userProgress[type] = progress
    }
    
    private func calculateDailyStreak(from games: [WatchGameRecord]) -> Int {
        guard !games.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let sortedDates = games.map { calendar.startOfDay(for: $0.date) }.sorted(by: >)
        
        var streak = 1
        var currentDate = sortedDates[0]
        
        for i in 1..<sortedDates.count {
            let nextDate = sortedDates[i]
            if calendar.dateComponents([.day], from: nextDate, to: currentDate).day == 1 {
                streak += 1
                currentDate = nextDate
            } else if nextDate != currentDate {
                break
            }
        }
        
        // Check if streak is still active (played today)
        let today = calendar.startOfDay(for: Date())
        if calendar.dateComponents([.day], from: sortedDates[0], to: today).day! > 0 {
            return 0 // Streak broken
        }
        
        return streak
    }
    
    private func countComebacks(in games: [WatchGameRecord]) -> Int {
        var comebackCount = 0
        
        for game in games where game.winner == "You" {
            guard let events = game.events else { continue }
            
            var maxDeficit = 0
            for event in events {
                let deficit = event.player2Score - event.player1Score
                maxDeficit = max(maxDeficit, deficit)
            }
            
            if maxDeficit >= 5 {
                comebackCount += 1
            }
        }
        
        return comebackCount
    }
    
    private func isHoliday(date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        
        // Major US holidays
        let holidays = [
            (1, 1),   // New Year's Day
            (7, 4),   // Independence Day
            (12, 25), // Christmas
            (12, 31), // New Year's Eve
        ]
        
        return holidays.contains { $0.0 == components.month && $0.1 == components.day }
    }
    
    private func calculateTotalPoints() {
        totalPoints = userProgress.values.reduce(0) { total, progress in
            guard let tier = progress.highestTierAchieved else { return total }
            
            // Special case for Diamond Hands
            if progress.type == .diamondHands {
                return total + 500
            }
            
            // For single-tier achievements, just add the tier points
            if let definition = AchievementDefinitions.shared.definitions[progress.type],
               definition.tiers.count == 1 {
                return total + tier.points
            }
            
            // For multi-tier achievements, add points for all achieved tiers
            var tierPoints = 0
            for achievedTier in AchievementTier.allCases where achievedTier.rawValue <= tier.rawValue {
                tierPoints += achievedTier.points
            }
            
            return total + tierPoints
        }
    }
    
    // MARK: - Persistence & Sync (unchanged)
    private func saveProgress() {
        if let encoded = try? JSONEncoder().encode(userProgress) {
            userDefaults.set(encoded, forKey: progressKey)
        }
        userDefaults.set(totalPoints, forKey: pointsKey)
    }
    
    private func loadProgress() {
        if let data = userDefaults.data(forKey: progressKey),
           let decoded = try? JSONDecoder().decode([AchievementType: AchievementProgress].self, from: data) {
            userProgress = decoded
        }
        totalPoints = userDefaults.integer(forKey: pointsKey)
        if totalPoints == 0 {
            calculateTotalPoints()
        }
    }

    /// Resets all achievement data for sign out / account switch
    func resetUserData() {
        userProgress.removeAll()
        totalPoints = 0
        newlyUnlockedAchievements.removeAll()
        userDefaults.removeObject(forKey: progressKey)
        userDefaults.removeObject(forKey: pointsKey)
    }

    // Firebase sync methods remain the same...
    func syncToFirebase() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        do {
            var achievementData: [String: Any] = [
                "userId": userId,
                "totalPoints": totalPoints,
                "lastUpdated": Timestamp()
            ]
            
            var progressArray: [[String: Any]] = []
            for (type, progress) in userProgress {
                var progressDict: [String: Any] = [
                    "type": type.rawValue,
                    "currentValue": progress.currentValue,
                    "dateLastUpdated": Timestamp(date: progress.dateLastUpdated)
                ]
                
                if let tier = progress.highestTierAchieved {
                    progressDict["highestTierAchieved"] = tier.rawValue
                }
                
                progressArray.append(progressDict)
            }
            achievementData["progress"] = progressArray
            
            try await db.collection("userAchievements")
                .document(userId)
                .setData(achievementData)
            
            print("✅ Achievements synced to Firebase")
            
        } catch {
            print("Failed to sync achievements to Firebase: \(error)")
        }
    }
    
    func loadFromFirebase() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        do {
            let document = try await db.collection("userAchievements")
                .document(userId)
                .getDocument()
            
            guard let data = document.data() else { return }
            
            if let progressArray = data["progress"] as? [[String: Any]] {
                var newProgress: [AchievementType: AchievementProgress] = [:]
                
                for item in progressArray {
                    if let typeString = item["type"] as? String,
                       let type = AchievementType(rawValue: typeString),
                       let currentValue = item["currentValue"] as? Int,
                       let dateTimestamp = item["dateLastUpdated"] as? Timestamp {
                        
                        var progress = AchievementProgress(type: type)
                        progress.currentValue = currentValue
                        progress.dateLastUpdated = dateTimestamp.dateValue()
                        
                        if let tierRawValue = item["highestTierAchieved"] as? Int,
                           let tier = AchievementTier(rawValue: tierRawValue) {
                            progress.highestTierAchieved = tier
                        }
                        
                        newProgress[type] = progress
                    }
                }
                
                await MainActor.run {
                    self.userProgress = newProgress
                    self.calculateTotalPoints()
                }
            }
            
            print("✅ Achievements loaded from Firebase")
            
        } catch {
            print("Failed to load achievements from Firebase: \(error)")
        }
    }
    
    private func setupAutoSync() {
        $userProgress
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.syncToFirebase()
                }
            }
            .store(in: &cancellables)
        
        Task {
            await loadFromFirebase()
        }
    }
    
    func getTopAchievements(count: Int = 5) -> [(AchievementDefinition, AchievementProgress)] {
        var achievements: [(AchievementDefinition, AchievementProgress)] = []
        
        for (type, progress) in userProgress {
            guard progress.highestTierAchieved != nil,
                  let definition = AchievementDefinitions.shared.definitions[type] else { continue }
            achievements.append((definition, progress))
        }
        
        return achievements
            .sorted { a, b in
                let tierA = a.1.highestTierAchieved?.rawValue ?? 0
                let tierB = b.1.highestTierAchieved?.rawValue ?? 0
                if tierA != tierB {
                    return tierA > tierB
                }
                return (a.1.highestTierAchieved?.points ?? 0) > (b.1.highestTierAchieved?.points ?? 0)
            }
            .prefix(count)
            .map { $0 }
    }
    
    func acknowledgeNewAchievements() {
        newlyUnlockedAchievements.removeAll()
    }

    // MARK: - Clear All Achievements
    func clearAllAchievements() {
        userProgress.removeAll()
        totalPoints = 0
        newlyUnlockedAchievements.removeAll()

        // Clear from UserDefaults
        userDefaults.removeObject(forKey: progressKey)
        userDefaults.removeObject(forKey: pointsKey)

        print("🧹 Cleared all achievements")
    }
}
