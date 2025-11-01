//
//  CompleteUserHealthManager.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/29/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import CloudKit
import Combine

// MARK: - Complete User Health Manager
class CompleteUserHealthManager: ObservableObject {
    static let shared = CompleteUserHealthManager()
    
    // Published properties
    @Published var currentUser: EnhancedPointUser?
    @Published var isSyncing = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var healthKitAuthorized = false
    
    // Managers
    private let authManager = AuthenticationManager.shared
    private let healthKitManager = EnhancedHealthKitManager.shared
    private let gameSyncManager = GameSyncManager.shared
    private let cloudKitManager = CloudKitManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    enum SyncStatus {
        case idle, syncing, success, error(String)
    }
    
    private init() {
        setupSubscriptions()
    }
    
    // MARK: - Enhanced User Model
    struct EnhancedPointUser: Codable {
        // Base user info
        var pointUser: PointUser
        
        // User preferences (from AppData)
        var hapticFeedback: Bool = true
        var soundEffects: Bool = false
        
        // Sport-specific settings
        var pickleballSettings: SportSettings
        var tennisSettings: SportSettings
        var padelSettings: SportSettings
        
        // Health statistics
        var totalCaloriesBurned: Double = 0
        var totalActiveMinutes: Int = 0
        var averageHeartRate: Double = 0
        var lastWorkoutDate: Date?
        
        // Sync metadata
        var lastLocalUpdate: Date = Date()
        var lastCloudSync: Date?
        
        struct SportSettings: Codable {
            var scoreLimit: Int?
            var winByTwo: Bool
            var matchFormat: String
            var preferredGameType: String
            
            init(for sport: String) {
                switch sport {
                case "Pickleball":
                    scoreLimit = 11
                    winByTwo = true
                    matchFormat = "bestOf3"
                    preferredGameType = "doubles"
                case "Tennis":
                    scoreLimit = nil
                    winByTwo = true
                    matchFormat = "bestOf3"
                    preferredGameType = "singles"
                case "Padel":
                    scoreLimit = nil
                    winByTwo = true
                    matchFormat = "bestOf3"
                    preferredGameType = "doubles"
                default:
                    scoreLimit = 21
                    winByTwo = true
                    matchFormat = "single"
                    preferredGameType = "singles"
                }
            }
        }
        
        init(from pointUser: PointUser) {
            self.pointUser = pointUser
            self.pickleballSettings = SportSettings(for: "Pickleball")
            self.tennisSettings = SportSettings(for: "Tennis")
            self.padelSettings = SportSettings(for: "Padel")
        }
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        // Listen for authentication changes
        authManager.$currentUser
            .compactMap { $0 }
            .sink { [weak self] user in
                Task {
                    await self?.loadOrCreateUserData(for: user)
                }
            }
            .store(in: &cancellables)
        
        // Listen for health kit authorization
        healthKitManager.$isAuthorized
            .sink { [weak self] authorized in
                self?.healthKitAuthorized = authorized
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Data Management
    private func loadOrCreateUserData(for pointUser: PointUser) async {
        // Try local first
        if let localData = loadLocalUserData(userId: pointUser.id) {
            await MainActor.run {
                self.currentUser = localData
            }
        } else {
            // Create new enhanced user
            let enhancedUser = EnhancedPointUser(from: pointUser)
            await MainActor.run {
                self.currentUser = enhancedUser
            }
            saveLocalUserData(enhancedUser)
        }
        
        // Sync from cloud
        await syncFromCloud(userId: pointUser.id)
        
        // Request HealthKit if needed
        if !healthKitAuthorized {
            Task {
                try? await healthKitManager.requestAuthorization()
            }
        }
    }
    
    func updateUserData(_ updates: (inout EnhancedPointUser) -> Void) {
        guard var user = currentUser else { return }
        
        updates(&user)
        user.lastLocalUpdate = Date()
        
        currentUser = user
        saveLocalUserData(user)
        
        // Sync to cloud in background
        Task {
            await syncToCloud()
        }
    }
    
    // MARK: - Update Health Stats from Watch
    func updateHealthStats(from healthData: [String: Any]) async {
        updateUserData { user in
            if let calories = healthData["totalCalories"] as? Double {
                user.totalCaloriesBurned += calories
            }
            
            if let duration = healthData["duration"] as? TimeInterval {
                user.totalActiveMinutes += Int(duration / 60)
            }
            
            if let avgHR = healthData["averageHeartRate"] as? Double {
                // Update rolling average
                let totalGames = user.pointUser.totalGamesPlayed
                if totalGames > 0 {
                    let totalHR = user.averageHeartRate * Double(totalGames - 1)
                    user.averageHeartRate = (totalHR + avgHR) / Double(totalGames)
                } else {
                    user.averageHeartRate = avgHR
                }
            }
            
            user.lastWorkoutDate = Date()
        }
    }
    
    // MARK: - Game Recording with Health
    func recordGameWithHealth(_ gameRecord: WatchGameRecord) async {
        guard let userId = authManager.currentUser?.id else { return }
        
        // End an active workout session if one is running
        if healthKitManager.isWorkoutActive {
            _ = await healthKitManager.endWorkout()
        }
        
        // Update user statistics
        updateUserData { user in
            user.pointUser.totalGamesPlayed += 1
            if gameRecord.winner == "You" {
                user.pointUser.totalWins += 1
            }
            
            // Update health stats from the game record's health data
            if let health = gameRecord.healthData {
                user.totalCaloriesBurned += health.totalCalories
                user.totalActiveMinutes += Int(gameRecord.elapsedTime / 60)
                
                // Update average heart rate
                let totalHR = user.averageHeartRate * Double(user.pointUser.totalGamesPlayed - 1)
                user.averageHeartRate = (totalHR + health.averageHeartRate) / Double(user.pointUser.totalGamesPlayed)
                
                user.lastWorkoutDate = Date()
            }
        }
        
        // Save game directly - it already has health data in it
        do {
            try await gameSyncManager.saveGame(gameRecord)
            print("✅ Game saved" + (gameRecord.healthData != nil ? " with health data" : ""))
        } catch {
            print("Failed to save game: \(error)")
        }
        
        // Check achievements and update watch
        WatchConnectivityManager.shared.addManualGame(gameRecord)
    }
    
    // MARK: - Health Tracking
    func startWorkoutTracking(sport: String, gameType: String) async throws {
        guard healthKitAuthorized else {
            try await healthKitManager.requestAuthorization()
            return
        }
        
        try await healthKitManager.startWorkout(sport: sport, gameType: gameType)
    }
    
    func pauseWorkout() {
        healthKitManager.pauseWorkout()
    }
    
    func resumeWorkout() {
        healthKitManager.resumeWorkout()
    }
    
    func endWorkout() async -> WorkoutSummary? {
        return await healthKitManager.endWorkout()
    }
    
    // MARK: - Cloud Sync
    private func syncToCloud() async {
        guard let user = currentUser else { return }
        
        await MainActor.run {
            isSyncing = true
            syncStatus = .syncing
        }
        
        do {
            // Save to Firestore
            try await saveToFirestore(user)
            
            // Save to CloudKit if available
            if cloudKitManager.isCloudKitAvailable {
                try await saveToCloudKit(user)
            }
            
            await MainActor.run {
                currentUser?.lastCloudSync = Date()
                syncStatus = .success
            }
            
        } catch {
            await MainActor.run {
                syncStatus = .error(error.localizedDescription)
            }
        }
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    private func syncFromCloud(userId: String) async {
        // Fetch from Firestore
        if let firestoreData = try? await fetchFromFirestore(userId: userId) {
            await MainActor.run {
                if let currentData = self.currentUser,
                   firestoreData.lastLocalUpdate > currentData.lastLocalUpdate {
                    self.currentUser = firestoreData
                }
            }
        }
        
        // Also check CloudKit
        if cloudKitManager.isCloudKitAvailable,
           let cloudData = try? await fetchFromCloudKit(userId: userId) {
            await MainActor.run {
                if let currentData = self.currentUser,
                   cloudData.lastLocalUpdate > currentData.lastLocalUpdate {
                    self.currentUser = cloudData
                }
            }
        }
    }
    
    // MARK: - Game Save with Health (Now largely redundant but kept for potential other uses)
    private func saveGameWithHealthData(_ game: WatchGameRecord, healthSummary: WorkoutSummary?) async {
        // If we have a health summary, we need to create a new game record with updated health data
        var gameToSave = game
        
        if let summary = healthSummary {
            // Create health data from the summary
            let healthData = WatchGameHealthData(
                averageHeartRate: summary.averageHeartRate,
                totalCalories: summary.totalCalories
            )
            
            // Create a new game record with the health data
            gameToSave = WatchGameRecord(
                id: game.id,
                date: game.date,
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
                healthData: healthData,  // Use the new health data
                setHistory: game.setHistory // FIXED: Include set history
            )
        }
        
        // Save using GameSyncManager's regular saveGame method
        do {
            try await gameSyncManager.saveGame(gameToSave)
            print("✅ Game saved" + (gameToSave.healthData != nil ? " with health data" : ""))
        } catch {
            print("Failed to save game with health data: \(error)")
        }
    }
    
    // MARK: - Local Storage
    private func saveLocalUserData(_ user: EnhancedPointUser) {
        guard let encoded = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(encoded, forKey: "enhancedUser_\(user.pointUser.id)")
    }
    
    private func loadLocalUserData(userId: String) -> EnhancedPointUser? {
        guard let data = UserDefaults.standard.data(forKey: "enhancedUser_\(userId)"),
              let user = try? JSONDecoder().decode(EnhancedPointUser.self, from: data) else {
            return nil
        }
        return user
    }
    
    // MARK: - Firestore Integration
    private func saveToFirestore(_ user: EnhancedPointUser) async throws {
        let db = Firestore.firestore()
        
        // Update PointUser document
        try await db.collection("users").document(user.pointUser.id).setData(from: user.pointUser, merge: true)
        
        // Save enhanced data separately
        let enhancedData: [String: Any] = [
            "hapticFeedback": user.hapticFeedback,
            "soundEffects": user.soundEffects,
            "totalCaloriesBurned": user.totalCaloriesBurned,
            "totalActiveMinutes": user.totalActiveMinutes,
            "averageHeartRate": user.averageHeartRate,
            "lastWorkoutDate": user.lastWorkoutDate as Any,
            "lastLocalUpdate": Timestamp(date: user.lastLocalUpdate),
            "pickleballSettings": try Firestore.Encoder().encode(user.pickleballSettings),
            "tennisSettings": try Firestore.Encoder().encode(user.tennisSettings),
            "padelSettings": try Firestore.Encoder().encode(user.padelSettings)
        ]
        
        try await db.collection("userSettings").document(user.pointUser.id).setData(enhancedData, merge: true)
    }
    
    private func fetchFromFirestore(userId: String) async throws -> EnhancedPointUser? {
        let db = Firestore.firestore()
        
        // Fetch base user
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let pointUser = try? userDoc.data(as: PointUser.self) else { return nil }
        
        // Fetch enhanced data
        let settingsDoc = try await db.collection("userSettings").document(userId).getDocument()
        
        var enhancedUser = EnhancedPointUser(from: pointUser)
        
        if let settings = settingsDoc.data() {
            enhancedUser.hapticFeedback = settings["hapticFeedback"] as? Bool ?? true
            enhancedUser.soundEffects = settings["soundEffects"] as? Bool ?? false
            enhancedUser.totalCaloriesBurned = settings["totalCaloriesBurned"] as? Double ?? 0
            enhancedUser.totalActiveMinutes = settings["totalActiveMinutes"] as? Int ?? 0
            enhancedUser.averageHeartRate = settings["averageHeartRate"] as? Double ?? 0
            
            if let timestamp = settings["lastWorkoutDate"] as? Timestamp {
                enhancedUser.lastWorkoutDate = timestamp.dateValue()
            }
            
            // Decode sport settings
            if let pbData = settings["pickleballSettings"] as? [String: Any] {
                enhancedUser.pickleballSettings = try Firestore.Decoder().decode(EnhancedPointUser.SportSettings.self, from: pbData)
            }
            if let tennisData = settings["tennisSettings"] as? [String: Any] {
                enhancedUser.tennisSettings = try Firestore.Decoder().decode(EnhancedPointUser.SportSettings.self, from: tennisData)
            }
            if let padelData = settings["padelSettings"] as? [String: Any] {
                enhancedUser.padelSettings = try Firestore.Decoder().decode(EnhancedPointUser.SportSettings.self, from: padelData)
            }
        }
        
        return enhancedUser
    }
    
    // MARK: - CloudKit Integration
    private func saveToCloudKit(_ user: EnhancedPointUser) async throws {
        let record = CKRecord(recordType: "UserData", recordID: CKRecord.ID(recordName: "user_\(user.pointUser.id)"))
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        record["userData"] = String(data: data, encoding: .utf8)
        record["lastUpdate"] = user.lastLocalUpdate
        
        _ = try await cloudKitManager.saveRecord(record)
    }
    
    private func fetchFromCloudKit(userId: String) async throws -> EnhancedPointUser? {
        let recordID = CKRecord.ID(recordName: "user_\(userId)")
        
        do {
            let record = try await cloudKitManager.fetchRecord(recordID)
            
            guard let jsonString = record["userData"] as? String,
                  let data = jsonString.data(using: .utf8) else {
                return nil
            }
            
            return try JSONDecoder().decode(EnhancedPointUser.self, from: data)
            
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return nil
            }
            throw error
        }
    }
}

// MARK: - AppData Bridge
// Create a separate class to handle the cancellables
private class AppDataSubscriptionHolder {
    static var cancellables = Set<AnyCancellable>()
}

extension AppData {
    func syncWithUserHealthManager() {
        CompleteUserHealthManager.shared.$currentUser
            .compactMap { $0 }
            .sink { [weak self] enhancedUser in
                // Update AppData from enhanced user
                self?.displayName = enhancedUser.pointUser.displayName
                self?.duprScore = enhancedUser.pointUser.duprScore ?? "3.8"
                self?.utrScore = enhancedUser.pointUser.utrScore ?? "5.5"
                self?.playtomicScore = enhancedUser.pointUser.playtomicScore ?? "4.2"
                
                // Preferences
                self?.hapticFeedback = enhancedUser.hapticFeedback
                self?.soundEffects = enhancedUser.soundEffects
                
                // Play styles
                if let pbStyle = enhancedUser.pointUser.pickleballPlayStyle,
                   let style = PickleballPlayStyle(rawValue: pbStyle) {
                    self?.pickleballPlayStyle = style
                }
                
                if let tennisStyle = enhancedUser.pointUser.tennisPlayStyle,
                   let style = TennisPlayStyle(rawValue: tennisStyle) {
                    self?.tennisPlayStyle = style
                }
                
                if let padelStyle = enhancedUser.pointUser.padelPlayStyle,
                   let style = PadelPlayStyle(rawValue: padelStyle) {
                    self?.padelPlayStyle = style
                }
            }
            .store(in: &AppDataSubscriptionHolder.cancellables)
    }
}
