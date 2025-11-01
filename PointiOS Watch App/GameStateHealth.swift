//
//  GameStateHealth.swift
//  ClaudePoint Watch App
//
//  Extension to add health tracking to GameState
//

import Foundation

extension GameState {
    private var healthKitManager: WatchHealthKitManager {
        WatchHealthKitManager.shared
    }
    
    var isTrackingHealth: Bool {
        healthKitManager.isWorkoutActive
    }
    
    func startHealthTracking() {
        Task {
            do {
                try await healthKitManager.startWorkout(
                    sport: "Pickleball",
                    gameType: gameType == .singles ? "Singles" : "Doubles"
                )
                print("🏃 Health tracking started for game")
            } catch {
                print("Failed to start health tracking: \(error)")
                // Continue game without health tracking
            }
        }
    }
    
    func endHealthTracking() async -> WorkoutSummary? {
        guard isTrackingHealth else {
            print("⚠️ Health tracking was not active")
            return nil
        }
        
        let summary = await healthKitManager.endWorkout()
        if let summary = summary {
            print("✅ Health tracking ended - HR: \(Int(summary.averageHeartRate)), Cal: \(Int(summary.totalCalories))")
        }
        return summary
    }
}
