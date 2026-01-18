//
//  EnhancedHealthKitManager.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/29/25.
//

import Foundation
import HealthKit
import Combine

class EnhancedHealthKitManager: ObservableObject {
    static let shared = EnhancedHealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var workoutBuilder: HKWorkoutBuilder?
    private var workoutConfiguration: HKWorkoutConfiguration?
    
    @Published var isAuthorized = false
    @Published var isWorkoutActive = false
    @Published var currentHeartRate: Double = 0
    @Published var averageHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var totalCalories: Double = 0
    @Published var workoutDuration: TimeInterval = 0
    
    // Real-time metrics during workout
    @Published var heartRateData: [(date: Date, value: Double)] = []
    @Published var calorieData: [(date: Date, value: Double)] = []
    
    private var workoutStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var heartRateQuery: HKQuery?
    private var activeEnergyQuery: HKQuery?
    
    // HealthKit types we want to read/write
    private let readTypes: Set<HKSampleType> = [
        .quantityType(forIdentifier: .heartRate)!,
        .quantityType(forIdentifier: .activeEnergyBurned)!,
        .quantityType(forIdentifier: .basalEnergyBurned)!,
        .quantityType(forIdentifier: .distanceWalkingRunning)!,
        .workoutType()
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        .workoutType(),
        .quantityType(forIdentifier: .activeEnergyBurned)!,
        .quantityType(forIdentifier: .heartRate)!
    ]
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        
        await MainActor.run {
            self.isAuthorized = true
        }
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Check authorization for each type
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let status = healthStore.authorizationStatus(for: heartRateType)
        
        DispatchQueue.main.async {
            self.isAuthorized = (status == .sharingAuthorized)
        }
    }
    
    // MARK: - Workout Session Management
    func startWorkout(sport: String, gameType: String) async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        // Map sport to HKWorkoutActivityType
        let activityType: HKWorkoutActivityType = {
            switch sport.lowercased() {
            case "tennis":
                return .tennis
            case "pickleball", "padel":
                return .racquetball // Closest match
            default:
                return .other
            }
        }()
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        
        // Create workout builder for iOS
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: nil)
        workoutBuilder = builder
        
        // Store configuration for later use
        self.workoutConfiguration = configuration
        
        // Start collection
        let startDate = Date()
        try await beginCollection(builder, startDate: startDate)
        
        await MainActor.run {
            self.isWorkoutActive = true
            self.workoutStartTime = startDate
            self.startMonitoringHealthData()
        }
    }
    
    func pauseWorkout() {
        // iOS doesn't have built-in pause for HKWorkoutBuilder
        // You'll need to track pause state manually
    }
    
    func resumeWorkout() {
        // iOS doesn't have built-in resume for HKWorkoutBuilder
        // You'll need to track resume state manually
    }
    
    func endWorkout() async -> WorkoutSummary? {
        guard let builder = workoutBuilder,
              let workoutStartTime = workoutStartTime else { return nil }
        
        let endDate = Date()
        
        do {
            // End collection
            try await endCollection(builder, endDate: endDate)
            
            // Add samples to the workout
            if !heartRateData.isEmpty {
                let heartRateSamples = heartRateData.compactMap { data -> HKQuantitySample? in
                    let quantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: data.value)
                    return HKQuantitySample(
                        type: HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                        quantity: quantity,
                        start: data.date,
                        end: data.date
                    )
                }
                let samples = heartRateSamples.map { $0 as HKSample }
                try await addSamples(samples, to: builder)
            }
            
            // Add energy samples
            if activeCalories > 0 {
                let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: activeCalories)
                let energySample = HKQuantitySample(
                    type: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                    quantity: energyQuantity,
                    start: workoutStartTime,
                    end: endDate
                )
                let samples: [HKSample] = [energySample]
                try await addSamples(samples, to: builder)
            }
            
            // Finish the workout
            _ = try await builder.finishWorkout()
            
            // Create workout summary
            let summary = WorkoutSummary(
                startDate: workoutStartTime,
                endDate: endDate,
                duration: endDate.timeIntervalSince(workoutStartTime),
                activeCalories: activeCalories,
                totalCalories: totalCalories,
                averageHeartRate: averageHeartRate,
                maxHeartRate: heartRateData.map { $0.value }.max() ?? 0,
                minHeartRate: heartRateData.map { $0.value }.min() ?? 0,
                heartRateData: heartRateData,
                calorieData: calorieData
            )
            
            // Reset state
            await MainActor.run {
                self.isWorkoutActive = false
                self.workoutStartTime = nil
                self.heartRateData = []
                self.calorieData = []
                self.currentHeartRate = 0
                self.averageHeartRate = 0
                self.activeCalories = 0
                self.totalCalories = 0
                self.stopMonitoringHealthData()
            }
            
            return summary
            
        } catch {
            print("Failed to end workout: \(error)")
            return nil
        }
    }

    private func beginCollection(_ builder: HKWorkoutBuilder, startDate: Date) async throws {
        try await withCheckedThrowingContinuation { continuation in
            builder.beginCollection(withStart: startDate) { success, error in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: error ?? HealthKitError.workoutStartFailed("Failed to begin collection")
                    )
                }
            }
        }
    }

    private func endCollection(_ builder: HKWorkoutBuilder, endDate: Date) async throws {
        try await withCheckedThrowingContinuation { continuation in
            builder.endCollection(withEnd: endDate) { success, error in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: error ?? HealthKitError.workoutStartFailed("Failed to end collection")
                    )
                }
            }
        }
    }

    private func addSamples(_ samples: [HKSample], to builder: HKWorkoutBuilder) async throws {
        guard !samples.isEmpty else { return }
        try await withCheckedThrowingContinuation { continuation in
            builder.add(samples) { success, error in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: error ?? HealthKitError.workoutStartFailed("Failed to add samples")
                    )
                }
            }
        }
    }
    
    // MARK: - Real-time Health Data Monitoring
    private func startMonitoringHealthData() {
        startHeartRateMonitoring()
        startCalorieMonitoring()
        startDurationTimer()
    }
    
    private func stopMonitoringHealthData() {
        if let heartRateQuery = heartRateQuery {
            healthStore.stop(heartRateQuery)
        }
        
        if let activeEnergyQuery = activeEnergyQuery {
            healthStore.stop(activeEnergyQuery)
        }
        
        cancellables.removeAll()
    }
    
    private func startHeartRateMonitoring() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
            if error != nil {
                completionHandler()
                return
            }
            
            // Fetch latest heart rate samples
            self?.fetchLatestHeartRateSamples()
            completionHandler()
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    private func fetchLatestHeartRateSamples() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: HKQuery.predicateForSamples(
                withStart: workoutStartTime,
                end: nil,
                options: .strictStartDate
            ),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] query, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            
            DispatchQueue.main.async {
                for sample in samples {
                    let heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    
                    // Check if we already have this sample
                    let alreadyExists = self?.heartRateData.contains { abs($0.date.timeIntervalSince(sample.startDate)) < 1 } ?? false
                    
                    if !alreadyExists {
                        self?.currentHeartRate = heartRate
                        self?.heartRateData.append((date: sample.startDate, value: heartRate))
                        
                        // Calculate average
                        let total = self?.heartRateData.reduce(0) { $0 + $1.value } ?? 0
                        self?.averageHeartRate = total / Double(self?.heartRateData.count ?? 1)
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startCalorieMonitoring() {
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        let query = HKObserverQuery(sampleType: energyType, predicate: nil) { [weak self] query, completionHandler, error in
            if error != nil {
                completionHandler()
                return
            }
            
            // Fetch latest calorie samples
            self?.fetchLatestCalorieSamples()
            completionHandler()
        }
        
        activeEnergyQuery = query
        healthStore.execute(query)
    }
    
    private func fetchLatestCalorieSamples() {
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: energyType,
            predicate: HKQuery.predicateForSamples(
                withStart: workoutStartTime,
                end: nil,
                options: .strictStartDate
            ),
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] query, samples, error in
            guard let samples = samples as? [HKQuantitySample], error == nil else { return }
            
            DispatchQueue.main.async {
                var totalActive: Double = 0
                
                for sample in samples {
                    let calories = sample.quantity.doubleValue(for: .kilocalorie())
                    totalActive += calories
                    
                    // Check if we already have this sample
                    let alreadyExists = self?.calorieData.contains { abs($0.date.timeIntervalSince(sample.startDate)) < 1 } ?? false
                    
                    if !alreadyExists {
                        self?.calorieData.append((date: sample.startDate, value: calories))
                    }
                }
                
                self?.activeCalories = totalActive
                self?.totalCalories = totalActive * 1.2 // Rough estimate including basal
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startDurationTimer() {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let startTime = self?.workoutStartTime else { return }
                self?.workoutDuration = Date().timeIntervalSince(startTime)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Historical Data Queries
    func fetchWorkoutData(for date: Date) async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )
        
        let samples: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            
            healthStore.execute(query)
        }
        
        return samples
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
    let heartRateData: [(date: Date, value: Double)]
    let calorieData: [(date: Date, value: Double)]
    
    private enum CodingKeys: String, CodingKey {
        case startDate, endDate, duration, activeCalories, totalCalories
        case averageHeartRate, maxHeartRate, minHeartRate
    }
    
    // Custom encoding/decoding for tuple arrays
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(duration, forKey: .duration)
        try container.encode(activeCalories, forKey: .activeCalories)
        try container.encode(totalCalories, forKey: .totalCalories)
        try container.encode(averageHeartRate, forKey: .averageHeartRate)
        try container.encode(maxHeartRate, forKey: .maxHeartRate)
        try container.encode(minHeartRate, forKey: .minHeartRate)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        activeCalories = try container.decode(Double.self, forKey: .activeCalories)
        totalCalories = try container.decode(Double.self, forKey: .totalCalories)
        averageHeartRate = try container.decode(Double.self, forKey: .averageHeartRate)
        maxHeartRate = try container.decode(Double.self, forKey: .maxHeartRate)
        minHeartRate = try container.decode(Double.self, forKey: .minHeartRate)
        heartRateData = []
        calorieData = []
    }
    
    init(startDate: Date, endDate: Date, duration: TimeInterval,
         activeCalories: Double, totalCalories: Double, averageHeartRate: Double,
         maxHeartRate: Double, minHeartRate: Double,
         heartRateData: [(date: Date, value: Double)],
         calorieData: [(date: Date, value: Double)]) {
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
        self.heartRateData = heartRateData
        self.calorieData = calorieData
    }
    
    // For CloudKit/Firebase sync
    var toDictionary: [String: Any] {
        return [
            "startDate": startDate,
            "endDate": endDate,
            "duration": duration,
            "activeCalories": activeCalories,
            "totalCalories": totalCalories,
            "averageHeartRate": averageHeartRate,
            "maxHeartRate": maxHeartRate,
            "minHeartRate": minHeartRate
        ]
    }
}

// MARK: - HealthKit Errors
enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case workoutStartFailed(String)
    case queryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "Please authorize HealthKit access in Settings"
        case .workoutStartFailed(let message):
            return "Failed to start workout: \(message)"
        case .queryFailed(let message):
            return "Failed to query health data: \(message)"
        }
    }
}

// MARK: - HKWorkoutActivityType Extension
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .tennis:
            return "Tennis"
        case .racquetball:
            return "Racquetball"
        default:
            return "Other"
        }
    }
}

// MARK: - Integration with Game Records
extension WatchGameRecord {
    mutating func addHealthData(_ summary: WorkoutSummary) {
        // Add health metrics to game record
        var additionalData: [String: Any] = [:]
        additionalData["activeCalories"] = summary.activeCalories
        additionalData["totalCalories"] = summary.totalCalories
        additionalData["averageHeartRate"] = summary.averageHeartRate
        additionalData["maxHeartRate"] = summary.maxHeartRate
        additionalData["minHeartRate"] = summary.minHeartRate
        
        // This would need to be added to your WatchGameRecord model
        // self.healthData = additionalData
    }
}
