//
//  HealthKitManager.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/21/25.
//

import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    // Published properties for UI updates
    @Published var todaysCalories: Double = 0
    @Published var averageHeartRate: Double = 0
    @Published var userAge: Int? = nil
    @Published var dateOfBirth: DateComponents? = nil
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    // HealthKit types we want to read
    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKQuantityType.workoutType(),
        HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)!
    ]
    
    // Optional: Add write types if you want to save workout data
    private let writeTypes: Set<HKSampleType> = [
        HKQuantityType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate)
    ]
    
    init() {
        checkHealthKitAvailability()
    }
    
    // MARK: - Authorization
    
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // Check current authorization status for heart rate (as a proxy)
        let heartRateType = HKQuantityType(.heartRate)
        authorizationStatus = healthStore.authorizationStatus(for: heartRateType)
        
        if authorizationStatus == .sharingAuthorized {
            isAuthorized = true
            fetchAllData()
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void = { _, _ in }) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            completion(false, nil)
            return
        }
        
        // Request both read and write permissions
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                
                if success {
                    self?.fetchAllData()
                    print("✅ HealthKit authorization granted")
                } else {
                    print("❌ HealthKit authorization denied or error")
                }
                
                completion(success, error)
            }
            
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Fetch All Data
    
    private func fetchAllData() {
        fetchDateOfBirth()
        fetchTodaysData()
    }
    
    func fetchTodaysData() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // Fetch calories
        fetchActiveCalories(from: startOfDay, to: now) { [weak self] calories in
            DispatchQueue.main.async {
                self?.todaysCalories = calories
            }
        }
        
        // Fetch heart rate
        fetchAverageHeartRate(from: startOfDay, to: now) { [weak self] heartRate in
            DispatchQueue.main.async {
                self?.averageHeartRate = heartRate
            }
        }
    }
    
    // MARK: - Date of Birth
    
    private func fetchDateOfBirth() {
        do {
            let dateOfBirthComponents = try healthStore.dateOfBirthComponents()
            
            DispatchQueue.main.async { [weak self] in
                self?.dateOfBirth = dateOfBirthComponents
                
                // Calculate age
                if let birthDate = dateOfBirthComponents.date {
                    let calendar = Calendar.current
                    let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
                    self?.userAge = ageComponents.year
                    
                    print("📅 User age: \(self?.userAge ?? 0)")
                }
            }
        } catch {
            print("Error fetching date of birth: \(error.localizedDescription)")
            // Date of birth might not be set in Health app
            // You can prompt user to add it in Health app or enter manually
        }
    }
    
    // MARK: - Active Calories
    
    func fetchActiveCalories(from start: Date, to end: Date, completion: @escaping (Double) -> Void) {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: energyType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result,
                  let sum = result.sumQuantity() else {
                completion(0)
                return
            }
            
            let calories = sum.doubleValue(for: .kilocalorie())
            completion(calories)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Heart Rate
    
    func fetchAverageHeartRate(from start: Date, to end: Date, completion: @escaping (Double) -> Void) {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, error in
            guard let result = result,
                  let average = result.averageQuantity() else {
                completion(0)
                return
            }
            
            let heartRate = average.doubleValue(for: HKUnit(from: "count/min"))
            completion(heartRate)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Workout Session Support
    
    func fetchTodaysWorkoutData(completion: @escaping (Double, Double) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        var totalCalories: Double = 0
        var avgHeartRate: Double = 0
        
        let group = DispatchGroup()
        
        // Fetch calories
        group.enter()
        fetchActiveCalories(from: startOfDay, to: now) { calories in
            totalCalories = calories
            group.leave()
        }
        
        // Fetch heart rate
        group.enter()
        fetchAverageHeartRate(from: startOfDay, to: now) { heartRate in
            avgHeartRate = heartRate
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(totalCalories, avgHeartRate)
        }
    }
    
    // MARK: - Save Workout (iOS 17+ Compatible)
    
    func saveWorkout(
        sport: String,
        startDate: Date,
        endDate: Date,
        calories: Double,
        averageHeartRate: Double?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // Determine workout activity type based on sport
        let activityType: HKWorkoutActivityType = {
            switch sport.lowercased() {
            case "tennis":
                return .tennis
            case "pickleball":
                return .pickleball
            case "padel":
                return .racquetball // Closest match for padel
            default:
                return .other
            }
        }()
        
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        
        // Create the workout builder
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        // Begin collection
        builder.beginCollection(withStart: startDate) { success, error in
            guard success else {
                completion(false, error)
                return
            }
            
            // Add metadata
            let metadata: [String: Any] = [
                "Sport": sport,
                "Source": "PointiOS"
            ]
            builder.addMetadata(metadata) { success, error in
                guard success else {
                    completion(false, error)
                    return
                }
                
                // Add samples if needed (calories and heart rate)
                var samplesToAdd: [HKSample] = []
                
                // Add energy burned sample
                if calories > 0 {
                    let energyType = HKQuantityType(.activeEnergyBurned)
                    let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                    let energySample = HKQuantitySample(
                        type: energyType,
                        quantity: energyQuantity,
                        start: startDate,
                        end: endDate
                    )
                    samplesToAdd.append(energySample)
                }
                
                // Add heart rate sample if available
                if let heartRate = averageHeartRate, heartRate > 0 {
                    let heartRateType = HKQuantityType(.heartRate)
                    let heartRateQuantity = HKQuantity(unit: HKUnit(from: "count/min"), doubleValue: heartRate)
                    let heartRateSample = HKQuantitySample(
                        type: heartRateType,
                        quantity: heartRateQuantity,
                        start: startDate,
                        end: endDate
                    )
                    samplesToAdd.append(heartRateSample)
                }
                
                // Add samples to builder
                if !samplesToAdd.isEmpty {
                    builder.add(samplesToAdd) { success, error in
                        guard success else {
                            completion(false, error)
                            return
                        }
                        
                        // End collection and finish workout
                        self.finishWorkout(builder: builder, endDate: endDate, completion: completion)
                    }
                } else {
                    // No samples to add, just finish
                    self.finishWorkout(builder: builder, endDate: endDate, completion: completion)
                }
            }
        }
    }
    
    private func finishWorkout(builder: HKWorkoutBuilder, endDate: Date, completion: @escaping (Bool, Error?) -> Void) {
        builder.endCollection(withEnd: endDate) { success, error in
            guard success else {
                completion(false, error)
                return
            }
            
            // Finish the workout
            builder.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    if let _ = workout {
                        print("✅ Workout saved to HealthKit")
                        completion(true, nil)
                    } else {
                        print("❌ Error saving workout: \(error?.localizedDescription ?? "Unknown error")")
                        completion(false, error)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func getAgeGroup() -> String? {
        guard let age = userAge else { return nil }
        
        switch age {
        case 0..<18:
            return "Junior"
        case 18..<35:
            return "Open"
        case 35..<50:
            return "35+"
        case 50..<60:
            return "50+"
        case 60..<70:
            return "60+"
        case 70...:
            return "70+"
        default:
            return nil
        }
    }
    
    func getFormattedAge() -> String {
        guard let age = userAge else { return "Age not set" }
        return "\(age) years old"
    }
}
