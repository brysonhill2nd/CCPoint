//
//  WatchHealthKitManager.swift
//  ClaudePoint Watch App
//
//  Minimal HealthKit manager for background workout tracking
//

import Foundation
import HealthKit
import WatchKit

class WatchHealthKitManager: NSObject, ObservableObject {
    static let shared = WatchHealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    @Published var isAuthorized = false
    @Published var isWorkoutActive = false
    
    private var workoutStartTime: Date?
    private var currentHeartRate: Double = 0
    private var averageHeartRate: Double = 0
    private var activeCalories: Double = 0
    
    private let typesToShare: Set<HKSampleType> = [
        HKQuantityType.workoutType()
    ]
    
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.workoutType()
    ]
    
    override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        
        await MainActor.run {
            self.isAuthorized = true
        }
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let status = healthStore.authorizationStatus(for: heartRateType)
        
        DispatchQueue.main.async {
            self.isAuthorized = (status == .sharingAuthorized)
        }
    }
    
    func startWorkout(sport: String, gameType: String) async throws {
        guard isAuthorized else {
            try await requestAuthorization()
            return
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = sport.lowercased() == "tennis" ? .tennis : .racquetball
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutSession?.delegate = self
            
            builder = workoutSession?.associatedWorkoutBuilder()
            builder?.delegate = self
            
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // FIX: Replace beginCollection call
            let startDate = Date()

            // Start collecting data with completion handler
            builder?.beginCollection(withStart: startDate) { [weak self] success, error in
                if success {
                    DispatchQueue.main.async {
                        self?.workoutStartTime = startDate
                    }
                } else {
                    print("Failed to begin collection: \(error?.localizedDescription ?? "Unknown error")")
                }
            }

            // Start the workout session
            workoutSession?.startActivity(with: startDate)

            // Set the active state
            await MainActor.run {
                self.isWorkoutActive = true
                self.workoutStartTime = startDate
            }

            print("🏃 Health tracking started in background")
            
        } catch {
            throw HealthKitError.workoutStartFailed(error.localizedDescription)
        }
    }
    
    func endWorkout() async -> WorkoutSummary? {
        guard let builder = builder,
              let workoutStartTime = workoutStartTime else { return nil }
        
        let endDate = Date()
        workoutSession?.end()
        
        do {
            try await withCheckedThrowingContinuation { continuation in
                builder.endCollection(withEnd: endDate) { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? HealthKitError.workoutStartFailed("Failed to end collection"))
                    }
                }
            }
            let workout = try await builder.finishWorkout()
            
            let activeEnergy = workout?.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? activeCalories
            let duration = workout?.duration ?? endDate.timeIntervalSince(workoutStartTime)
            
            let summary = WorkoutSummary(
                startDate: workoutStartTime,
                endDate: endDate,
                duration: duration,
                activeCalories: activeEnergy,
                totalCalories: activeEnergy * 1.2,
                averageHeartRate: averageHeartRate > 0 ? averageHeartRate : 120, // Default if no HR data
                maxHeartRate: currentHeartRate > 0 ? currentHeartRate : 140,
                minHeartRate: currentHeartRate > 0 ? currentHeartRate : 100
            )
            
            await MainActor.run {
                self.isWorkoutActive = false
                self.workoutStartTime = nil
                self.currentHeartRate = 0
                self.averageHeartRate = 0
                self.activeCalories = 0
            }
            
            print("🏁 Health tracking ended - Avg HR: \(Int(summary.averageHeartRate)), Calories: \(Int(summary.totalCalories))")
            
            return summary
            
        } catch {
            print("Failed to end workout: \(error)")
            return nil
        }
    }
}

// MARK: - Delegates
extension WatchHealthKitManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        DispatchQueue.main.async {
            self.isWorkoutActive = (toState == .running)
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print("Workout session failed: \(error)")
    }
}

extension WatchHealthKitManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            switch quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    let heartRate = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
                    self.currentHeartRate = heartRate
                    
                    if let avgStats = workoutBuilder.statistics(for: quantityType)?.averageQuantity() {
                        self.averageHeartRate = avgStats.doubleValue(for: HKUnit(from: "count/min"))
                    }
                }
                
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    let energy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    self.activeCalories = energy
                }
                
            default:
                break
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}

// MARK: - Workout Summary Model
struct WorkoutSummary: Codable {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let activeCalories: Double
    let totalCalories: Double
    let averageHeartRate: Double
    let maxHeartRate: Double
    let minHeartRate: Double
}

// MARK: - HealthKit Errors
enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case workoutStartFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "Please authorize HealthKit access in Settings"
        case .workoutStartFailed(let message):
            return "Failed to start workout: \(message)"
        }
    }
}
