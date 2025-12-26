//
//  GameStateHealth.swift
//  ClaudePoint Watch App
//
//  Extension to add health tracking to GameState, TennisGameState, and PadelGameState
//

import Foundation

// MARK: - Cached Health Summary Storage
// Using a simple actor to store cached health summaries by game ID
actor HealthSummaryCache {
    static let shared = HealthSummaryCache()
    private var cache: [UUID: WorkoutSummary] = [:]
    private var startedTracking: Set<UUID> = []

    func get(_ id: UUID) -> WorkoutSummary? {
        return cache[id]
    }

    func set(_ id: UUID, summary: WorkoutSummary) {
        cache[id] = summary
    }

    func remove(_ id: UUID) {
        cache.removeValue(forKey: id)
        startedTracking.remove(id)
    }

    func markStarted(_ id: UUID) {
        startedTracking.insert(id)
    }

    func hasStarted(_ id: UUID) -> Bool {
        return startedTracking.contains(id)
    }
}

// MARK: - Health Tracking Protocol
protocol HealthTrackable {
    var healthKitManager: WatchHealthKitManager { get }
    var isTrackingHealth: Bool { get }
    var sportName: String { get }
    var gameTypeString: String { get }
    var healthTrackingID: UUID { get }
    func startHealthTracking()
    func endHealthTracking() async -> WorkoutSummary?
}

// MARK: - GameState Extension (Pickleball)
extension GameState: HealthTrackable {
    var healthKitManager: WatchHealthKitManager {
        WatchHealthKitManager.shared
    }

    var isTrackingHealth: Bool {
        healthKitManager.isWorkoutActive
    }

    var sportName: String { "Pickleball" }

    var gameTypeString: String {
        gameType == .singles ? "Singles" : "Doubles"
    }

    var healthTrackingID: UUID { id }

    func startHealthTracking() {
        Task {
            // Mark that we've started tracking for this game
            await HealthSummaryCache.shared.markStarted(healthTrackingID)
            do {
                try await healthKitManager.startWorkout(
                    sport: sportName,
                    gameType: gameTypeString
                )
                print("🏃 Health tracking started for \(sportName)")
            } catch {
                print("Failed to start health tracking: \(error)")
            }
        }
    }

    func endHealthTracking() async -> WorkoutSummary? {
        // Check cache first - allows multiple calls to return same result
        if let cached = await HealthSummaryCache.shared.get(healthTrackingID) {
            print("📦 Returning cached health summary")
            return cached
        }

        // If we started tracking but workout isn't active yet, wait a moment
        let didStart = await HealthSummaryCache.shared.hasStarted(healthTrackingID)
        if didStart && !isTrackingHealth {
            print("⏳ Waiting for health tracking to become active...")
            // Wait up to 2 seconds for workout to start
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                if isTrackingHealth { break }
            }
        }

        guard isTrackingHealth else {
            print("⚠️ Health tracking was not active")
            return nil
        }

        let summary = await healthKitManager.endWorkout()
        if let summary = summary {
            await HealthSummaryCache.shared.set(healthTrackingID, summary: summary)
            print("✅ Health tracking ended - HR: \(Int(summary.averageHeartRate)), Cal: \(Int(summary.totalCalories))")
        }
        return summary
    }
}

// MARK: - TennisGameState Extension
extension TennisGameState: HealthTrackable {
    var healthKitManager: WatchHealthKitManager {
        WatchHealthKitManager.shared
    }

    var isTrackingHealth: Bool {
        healthKitManager.isWorkoutActive
    }

    var sportName: String { "Tennis" }

    var gameTypeString: String {
        gameType == .singles ? "Singles" : "Doubles"
    }

    var healthTrackingID: UUID { id }

    func startHealthTracking() {
        Task {
            // Mark that we've started tracking for this game
            await HealthSummaryCache.shared.markStarted(healthTrackingID)
            do {
                try await healthKitManager.startWorkout(
                    sport: sportName,
                    gameType: gameTypeString
                )
                print("🏃 Health tracking started for \(sportName)")
            } catch {
                print("Failed to start health tracking: \(error)")
            }
        }
    }

    func endHealthTracking() async -> WorkoutSummary? {
        // Check cache first - allows multiple calls to return same result
        if let cached = await HealthSummaryCache.shared.get(healthTrackingID) {
            print("📦 Returning cached health summary")
            return cached
        }

        // If we started tracking but workout isn't active yet, wait a moment
        let didStart = await HealthSummaryCache.shared.hasStarted(healthTrackingID)
        if didStart && !isTrackingHealth {
            print("⏳ Waiting for health tracking to become active...")
            // Wait up to 2 seconds for workout to start
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                if isTrackingHealth { break }
            }
        }

        guard isTrackingHealth else {
            print("⚠️ Health tracking was not active")
            return nil
        }

        let summary = await healthKitManager.endWorkout()
        if let summary = summary {
            await HealthSummaryCache.shared.set(healthTrackingID, summary: summary)
            print("✅ Health tracking ended - HR: \(Int(summary.averageHeartRate)), Cal: \(Int(summary.totalCalories))")
        }
        return summary
    }
}

// MARK: - PadelGameState Extension
extension PadelGameState: HealthTrackable {
    var healthKitManager: WatchHealthKitManager {
        WatchHealthKitManager.shared
    }

    var isTrackingHealth: Bool {
        healthKitManager.isWorkoutActive
    }

    var sportName: String { "Padel" }

    // Padel is always doubles
    var gameTypeString: String { "Doubles" }

    var healthTrackingID: UUID { id }

    func startHealthTracking() {
        Task {
            // Mark that we've started tracking for this game
            await HealthSummaryCache.shared.markStarted(healthTrackingID)
            do {
                try await healthKitManager.startWorkout(
                    sport: sportName,
                    gameType: gameTypeString
                )
                print("🏃 Health tracking started for \(sportName)")
            } catch {
                print("Failed to start health tracking: \(error)")
            }
        }
    }

    func endHealthTracking() async -> WorkoutSummary? {
        // Check cache first - allows multiple calls to return same result
        if let cached = await HealthSummaryCache.shared.get(healthTrackingID) {
            print("📦 Returning cached health summary")
            return cached
        }

        // If we started tracking but workout isn't active yet, wait a moment
        let didStart = await HealthSummaryCache.shared.hasStarted(healthTrackingID)
        if didStart && !isTrackingHealth {
            print("⏳ Waiting for health tracking to become active...")
            // Wait up to 2 seconds for workout to start
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                if isTrackingHealth { break }
            }
        }

        guard isTrackingHealth else {
            print("⚠️ Health tracking was not active")
            return nil
        }

        let summary = await healthKitManager.endWorkout()
        if let summary = summary {
            await HealthSummaryCache.shared.set(healthTrackingID, summary: summary)
            print("✅ Health tracking ended - HR: \(Int(summary.averageHeartRate)), Cal: \(Int(summary.totalCalories))")
        }
        return summary
    }
}
