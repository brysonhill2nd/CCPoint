//
//  UnifiedSyncManager.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/25/25.
//

import Foundation
import FirebaseAuth
import Combine

class UnifiedSyncManager: ObservableObject {
    static let shared = UnifiedSyncManager()
    
    private let firebaseSync = GameSyncManager.shared
    private let cloudKitSync = CloudKitManager.shared
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [String] = []
    
    private init() {
        loadLastSyncDate()
    }
    
    // MARK: - Sync Strategy
    enum SyncStrategy {
        case firebaseOnly
        case cloudKitOnly
        case both
        case automatic // Use CloudKit if available, fallback to Firebase
    }
    
    // MARK: - Save Game with Automatic Sync
    func saveGame(_ game: WatchGameRecord, strategy: SyncStrategy = .automatic) async {
        await MainActor.run {
            isSyncing = true
            syncErrors.removeAll()
        }
        
        var syncSuccessful = false
        
        switch strategy {
        case .firebaseOnly:
            await syncToFirebase(game)
            
        case .cloudKitOnly:
            await syncToCloudKit(game)
            
        case .both:
            await syncToBothServices(game)
            
        case .automatic:
            // Try CloudKit first (faster, works offline)
            if cloudKitSync.isCloudKitAvailable {
                await syncToCloudKit(game)
                // Also sync to Firebase for web access
                await syncToFirebase(game)
            } else {
                // Fallback to Firebase only
                await syncToFirebase(game)
            }
            syncSuccessful = syncErrors.isEmpty
        }
        
        if syncSuccessful {
            await MainActor.run {
                lastSyncDate = Date()
                saveLastSyncDate()
            }
        }
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    // MARK: - Fetch Games with Merge Strategy
    func fetchAllGames(limit: Int = 100) async -> [WatchGameRecord] {
        var allGames: [WatchGameRecord] = []
        var gameIds = Set<String>()
        
        // Fetch from Firebase
        if Auth.auth().currentUser != nil {
            do {
                let firebaseGames = try await firebaseSync.fetchUserGames(limit: limit)
                for game in firebaseGames {
                    if !gameIds.contains(game.id.uuidString) {
                        allGames.append(game)
                        gameIds.insert(game.id.uuidString)
                    }
                }
            } catch {
                print("Error fetching from Firebase: \(error)")
            }
        }
        
        // Fetch from CloudKit
        if cloudKitSync.isCloudKitAvailable,
           let userId = AuthenticationManager.shared.currentUser?.id {
            do {
                let cloudKitGames = try await cloudKitSync.fetchGames(for: userId, limit: limit)
                for game in cloudKitGames {
                    if !gameIds.contains(game.id.uuidString) {
                        allGames.append(game)
                        gameIds.insert(game.id.uuidString)
                    }
                }
            } catch {
                print("Error fetching from CloudKit: \(error)")
            }
        }
        
        // Sort by date (newest first)
        return allGames.sorted { $0.date > $1.date }
    }
    
    // MARK: - Sync All Local Games
    func syncAllLocalGames(_ games: [WatchGameRecord]) async {
        await MainActor.run {
            isSyncing = true
            syncErrors.removeAll()
        }
        
        // Sync to both services in parallel
        await withTaskGroup(of: Void.self) { group in
            // CloudKit sync
            if cloudKitSync.isCloudKitAvailable,
               let userId = AuthenticationManager.shared.currentUser?.id {
                group.addTask {
                    await self.cloudKitSync.syncAllGames(games, userId: userId)
                }
            }
            
            // Firebase sync
            if Auth.auth().currentUser != nil {
                group.addTask {
                    await self.firebaseSync.syncAllLocalGames(games)
                }
            }
        }
        
        await MainActor.run {
            lastSyncDate = Date()
            saveLastSyncDate()
            isSyncing = false
        }
    }
    
    // MARK: - Private Sync Methods
    private func syncToFirebase(_ game: WatchGameRecord) async {
        do {
            // GameSyncManager will handle the health data from the game record
            try await firebaseSync.saveGame(game)
            print("✅ Game synced to Firebase")
        } catch {
            await MainActor.run {
                syncErrors.append("Firebase: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncToCloudKit(_ game: WatchGameRecord) async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            await MainActor.run {
                syncErrors.append("CloudKit: No user ID available")
            }
            return
        }
        
        do {
            try await cloudKitSync.saveGame(game, userId: userId)
            print("✅ Game synced to CloudKit")
        } catch {
            await MainActor.run {
                syncErrors.append("CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    private func syncToBothServices(_ game: WatchGameRecord) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.syncToFirebase(game)
            }
            
            group.addTask {
                await self.syncToCloudKit(game)
            }
        }
    }
    
    // MARK: - User Profile Sync
    func syncUserProfile(_ user: PointUser) async {
        // Sync to CloudKit for offline access
        if cloudKitSync.isCloudKitAvailable {
            do {
                try await cloudKitSync.saveUserProfile(user)
                print("✅ User profile synced to CloudKit")
            } catch {
                print("Error syncing profile to CloudKit: \(error)")
            }
        }
        
        // Firebase sync is handled by AuthenticationManager
    }
    
    // MARK: - Persistence
    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastCloudSyncDate")
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudSyncDate") as? Date
    }
    
    // MARK: - Conflict Resolution
    func resolveConflicts(localGame: WatchGameRecord, cloudGame: WatchGameRecord) -> WatchGameRecord {
        // Simple strategy: most recent wins
        return localGame.date > cloudGame.date ? localGame : cloudGame
    }
    
    // MARK: - Background Sync
    func performBackgroundSync() async {
        guard !isSyncing else { return }

        // Check if we should sync (e.g., haven't synced in last hour)
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < 3600 {
            return
        }

        // Fetch local games that need syncing
        let localGames = WatchConnectivityManager.shared.receivedGames

        if !localGames.isEmpty {
            await syncAllLocalGames(localGames)
        }
    }

    // MARK: - Delete Games
    func deleteGames(_ games: [WatchGameRecord]) async {
        await MainActor.run {
            isSyncing = true
            syncErrors.removeAll()
        }

        // Delete from Firebase
        if Auth.auth().currentUser != nil {
            do {
                try await firebaseSync.deleteGames(games)
                print("✅ Games deleted from Firebase")
            } catch {
                await MainActor.run {
                    syncErrors.append("Firebase delete: \(error.localizedDescription)")
                }
            }
        }

        // Delete from CloudKit
        if cloudKitSync.isCloudKitAvailable,
           let userId = AuthenticationManager.shared.currentUser?.id {
            do {
                try await cloudKitSync.deleteGames(games, userId: userId)
                print("✅ Games deleted from CloudKit")
            } catch {
                await MainActor.run {
                    syncErrors.append("CloudKit delete: \(error.localizedDescription)")
                }
            }
        }

        await MainActor.run {
            isSyncing = false
        }
    }
}

// MARK: - Extension for WatchConnectivityManager
extension WatchConnectivityManager {
    func syncGameToCloud(_ game: WatchGameRecord) {
        Task {
            await UnifiedSyncManager.shared.saveGame(game)
        }
    }
}
