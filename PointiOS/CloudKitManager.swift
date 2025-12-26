// CloudKitManager.swift - Fixed with setHistory support
import Foundation
import CloudKit

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    let privateDatabase: CKDatabase
    private let subscriptionKeyPrefix = "CloudKitSubscriptionSetup-"
    
    @Published var isCloudKitAvailable = false
    @Published var cloudKitStatus: CKAccountStatus = .couldNotDetermine
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.success, .success):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    private init() {
        container = CKContainer(identifier: "iCloud.Bryson.PointiOS")
        privateDatabase = container.privateCloudDatabase
        checkCloudKitAvailability()
    }
    
    // MARK: - CloudKit Availability
    private func checkCloudKitAvailability() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.cloudKitStatus = status
                self?.isCloudKitAvailable = (status == .available)
                
                if let error = error {
                    print("❌ CloudKit account check error: \(error)")
                } else {
                    print("✅ CloudKit status: \(status.rawValue)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        return try await privateDatabase.save(record)
    }

    func fetchRecord(_ recordID: CKRecord.ID) async throws -> CKRecord {
        return try await privateDatabase.record(for: recordID)
    }

    // MARK: - Save Game to CloudKit
    func saveGame(_ game: WatchGameRecord, userId: String) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        await MainActor.run {
            syncStatus = .syncing
        }
        
        let record = CKRecord(recordType: "Game")
        
        // Set basic fields
        record["userId"] = userId
        record["date"] = game.date
        record["sportType"] = game.sportType
        record["gameType"] = game.gameType
        record["player1Score"] = game.player1Score
        record["player2Score"] = game.player2Score
        record["player1GamesWon"] = game.player1GamesWon
        record["player2GamesWon"] = game.player2GamesWon
        record["elapsedTime"] = game.elapsedTime
        record["winner"] = game.winner
        record["location"] = game.location
        
        // Save health data
        if let health = game.healthData {
            record["healthAverageHeartRate"] = health.averageHeartRate
            record["healthTotalCalories"] = health.totalCalories
        }
        
        // Save events
        if let events = game.events {
            let encoder = JSONEncoder()
            if let eventsData = try? encoder.encode(events) {
                record["events"] = eventsData
            }
        }
        
        // Save set history for Tennis/Padel
        if let setHistory = game.setHistory {
            let encoder = JSONEncoder()
            if let setHistoryData = try? encoder.encode(setHistory) {
                record["setHistory"] = setHistoryData
            }
        }
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            print("✅ Game saved to CloudKit: \(savedRecord.recordID)")
            if game.healthData != nil {
                print("✅ Including health data")
            }
            if game.setHistory != nil {
                print("✅ Including set history")
            }
            
            await MainActor.run {
                syncStatus = .success
            }
        } catch {
            await MainActor.run {
                syncStatus = .error(error.localizedDescription)
            }
            throw error
        }
    }
    
    // MARK: - Fetch Games from CloudKit
    func fetchGames(for userId: String, limit: Int = 50) async throws -> [WatchGameRecord] {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "Game", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let results = try await privateDatabase.records(matching: query, resultsLimit: limit)
            
            return results.matchResults.compactMap { _, result in
                switch result {
                case .success(let record):
                    return parseGameRecord(from: record)
                case .failure(let error):
                    print("Error fetching record: \(error)")
                    return nil
                }
            }
        } catch {
            throw CloudKitError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Parse Game Record
    private func parseGameRecord(from record: CKRecord) -> WatchGameRecord? {
        guard let date = record["date"] as? Date,
              let sportType = record["sportType"] as? String,
              let gameType = record["gameType"] as? String else {
            return nil
        }
        
        // Parse events
        var events: [GameEventData]? = nil
        if let eventsData = record["events"] as? Data {
            let decoder = JSONDecoder()
            events = try? decoder.decode([GameEventData].self, from: eventsData)
        }
        
        // Parse health data
        var healthData: WatchGameHealthData? = nil
        if let avgHR = record["healthAverageHeartRate"] as? Double,
           let calories = record["healthTotalCalories"] as? Double {
            healthData = WatchGameHealthData(
                averageHeartRate: avgHR,
                totalCalories: calories
            )
        }
        
        // Parse set history for Tennis/Padel
        var setHistory: [WatchSetScore]? = nil
        if let setHistoryData = record["setHistory"] as? Data {
            let decoder = JSONDecoder()
            setHistory = try? decoder.decode([WatchSetScore].self, from: setHistoryData)
        }
        
        return WatchGameRecord(
            id: UUID(),
            date: date,
            sportType: sportType,
            gameType: gameType,
            player1Score: record["player1Score"] as? Int ?? 0,
            player2Score: record["player2Score"] as? Int ?? 0,
            player1GamesWon: record["player1GamesWon"] as? Int ?? 0,
            player2GamesWon: record["player2GamesWon"] as? Int ?? 0,
            elapsedTime: record["elapsedTime"] as? TimeInterval ?? 0,
            winner: record["winner"] as? String,
            location: record["location"] as? String,
            events: events,
            healthData: healthData,
            setHistory: setHistory,
            shots: nil
        )
    }
    
    // MARK: - Save User Profile to CloudKit
    func saveUserProfile(_ user: PointUser) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }
        
        let recordID = CKRecord.ID(recordName: "userProfile_\(user.id)")
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)
        
        record["displayName"] = user.displayName
        record["email"] = user.email
        record["duprScore"] = user.duprScore
        record["utrScore"] = user.utrScore
        record["playtomicScore"] = user.playtomicScore
        record["pickleballPlayStyle"] = user.pickleballPlayStyle
        record["tennisPlayStyle"] = user.tennisPlayStyle
        record["padelPlayStyle"] = user.padelPlayStyle
        record["totalGamesPlayed"] = user.totalGamesPlayed
        record["totalWins"] = user.totalWins
        record["achievements"] = user.achievements
        record["lastUpdated"] = user.lastUpdated
        record["favoriteCourtLocation"] = user.favoriteCourtLocation
        
        do {
            _ = try await privateDatabase.save(record)
            print("✅ User profile saved to CloudKit")
        } catch {
            throw CloudKitError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sync All Games
    func syncAllGames(_ games: [WatchGameRecord], userId: String) async {
        await MainActor.run {
            syncStatus = .syncing
        }
        
        var successCount = 0
        var failureCount = 0
        
        for game in games {
            do {
                try await saveGame(game, userId: userId)
                successCount += 1
            } catch {
                failureCount += 1
                print("Failed to sync game \(game.id): \(error)")
            }
            
            // Add a small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        await MainActor.run {
            if failureCount > 0 {
                syncStatus = .error("Synced \(successCount) games, \(failureCount) failed")
            } else {
                syncStatus = .success
            }
        }
    }
    
    // MARK: - Setup Subscriptions
    func setupSubscriptions(userId: String) async throws {
        guard isCloudKitAvailable else { return }

        let predicate = NSPredicate(format: "userId == %@", userId)
        let subscription = CKQuerySubscription(
            recordType: "Game",
            predicate: predicate,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await privateDatabase.save(subscription)
            print("✅ CloudKit subscription created")
        } catch {
            print("Failed to create subscription: \(error)")
        }
    }

    func setupSubscriptionsIfNeeded(userId: String) async {
        let key = subscriptionKeyPrefix + userId
        if UserDefaults.standard.bool(forKey: key) {
            return
        }

        do {
            try await setupSubscriptions(userId: userId)
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            print("Failed to ensure subscription: \(error)")
        }
    }

    // MARK: - Delete Games
    func deleteGames(_ games: [WatchGameRecord], userId: String) async throws {
        guard isCloudKitAvailable else {
            throw CloudKitError.notAvailable
        }

        for game in games {
            // Query for the record with matching game ID
            let predicate = NSPredicate(format: "userId == %@ AND date == %@", userId, game.date as NSDate)
            let query = CKQuery(recordType: "Game", predicate: predicate)

            do {
                let results = try await privateDatabase.records(matching: query, resultsLimit: 1)

                for (recordID, result) in results.matchResults {
                    switch result {
                    case .success:
                        try await privateDatabase.deleteRecord(withID: recordID)
                        print("✅ Deleted game from CloudKit: \(recordID)")
                    case .failure(let error):
                        print("❌ Failed to delete game from CloudKit: \(error)")
                        throw CloudKitError.deleteFailed(error.localizedDescription)
                    }
                }
            } catch {
                print("❌ Failed to query/delete game from CloudKit: \(error)")
                throw CloudKitError.deleteFailed(error.localizedDescription)
            }
        }
    }
}

// MARK: - CloudKit Errors
enum CloudKitError: LocalizedError {
    case notAvailable
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        }
    }
}
