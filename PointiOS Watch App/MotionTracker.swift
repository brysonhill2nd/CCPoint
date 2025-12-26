import Foundation
import SwiftUI
import CoreMotion

enum DominantHand {
    case left
    case right
    case unknown
}

enum ShotType: String, CaseIterable, Identifiable, Codable {
    case serve = "Serve"
    case overhead = "Overhead"
    case powerShot = "Power Shot"
    case touchShot = "Touch Shot"
    case volley = "Volley"
    case unknown = "Unknown"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .serve: return "🎯"
        case .powerShot: return "💥"
        case .overhead: return "⚡️"
        case .volley: return "🛡️"
        case .touchShot: return "🪃"
        case .unknown: return "❓"
        }
    }

    func displayName(for sport: String, isBackhand: Bool = false) -> String {
        let handPrefix = isBackhand ? "BH " : ""

        switch sport {
        case "Pickleball":
            switch self {
            case .serve: return "Serve"
            case .overhead: return "Smash"
            case .powerShot: return "\(handPrefix)Drive"
            case .touchShot: return "\(handPrefix)Dink"
            case .volley: return "\(handPrefix)Volley"
            case .unknown: return "Unknown"
            }
        case "Tennis":
            switch self {
            case .serve: return "Serve"
            case .overhead: return "Smash"
            case .powerShot: return "\(handPrefix)Groundstroke"
            case .touchShot: return "\(handPrefix)Touch"
            case .volley: return "\(handPrefix)Volley"
            case .unknown: return "Unknown"
            }
        case "Padel":
            switch self {
            case .serve: return "Serve"
            case .overhead: return "Overhead"
            case .powerShot: return "\(handPrefix)Drive"
            case .touchShot: return "\(handPrefix)Touch"
            case .volley: return "\(handPrefix)Volley"
            case .unknown: return "Unknown"
            }
        default:
            return "\(handPrefix)\(rawValue)"
        }
    }
}

struct DetectedShot: Identifiable, Codable {
    let id: UUID
    let type: ShotType
    let intensity: Double
    let absoluteMagnitude: Double
    let timestamp: Date
    let isPointCandidate: Bool
    let gyroAngle: Double  // Angle in degrees from gyroscope
    let swingDuration: TimeInterval  // Duration of swing from start to peak
    let sport: String  // Which sport was being played
    let rallyReactionTime: TimeInterval?  // Time since last shot (for rally analysis)
    let associatedWithPoint: Bool  // Was this shot followed by a score?
    let isBackhand: Bool  // Detected from gyro Y-axis rotation direction

    var displayName: String {
        type.displayName(for: sport, isBackhand: isBackhand)
    }

    init(
        type: ShotType,
        intensity: Double,
        absoluteMagnitude: Double,
        timestamp: Date,
        isPointCandidate: Bool,
        gyroAngle: Double = 0,
        swingDuration: TimeInterval = 0,
        sport: String = "Pickleball",
        rallyReactionTime: TimeInterval? = nil,
        associatedWithPoint: Bool = false,
        isBackhand: Bool = false
    ) {
        self.id = UUID()
        self.type = type
        self.intensity = intensity
        self.absoluteMagnitude = absoluteMagnitude
        self.timestamp = timestamp
        self.isPointCandidate = isPointCandidate
        self.gyroAngle = gyroAngle
        self.swingDuration = swingDuration
        self.sport = sport
        self.rallyReactionTime = rallyReactionTime
        self.associatedWithPoint = associatedWithPoint
        self.isBackhand = isBackhand
    }
}

// MARK: - Sport-Specific Heuristics
struct SportHeuristics {
    let sport: String

    // Base thresholds for each sport
    var touchShotMagnitudeThreshold: Double {
        // touchShot = dink/slice/drop shot (soft touch)
        switch sport {
        case "Pickleball": return 2.0
        case "Tennis": return 2.8  // Tennis balls are heavier, higher impact
        case "Padel": return 2.5   // Padel between pickleball and tennis
        default: return 2.0
        }
    }

    var powerShotVsOverheadGyroThreshold: Double {
        // overhead has steeper angle (higher gyro rotation)
        // powerShot has flatter arc (lower gyro rotation)
        switch sport {
        case "Pickleball": return 45.0  // degrees
        case "Tennis": return 50.0      // Tennis smashes are steeper
        case "Padel": return 48.0       // Padel walls affect angles
        default: return 45.0
        }
    }

    var serveMagnitudeThreshold: Double {
        switch sport {
        case "Pickleball": return 1.5
        case "Tennis": return 2.2  // Tennis serves much harder
        case "Padel": return 1.8   // Padel serves underhand, less force
        default: return 1.5
        }
    }

    var volleyMagnitudeRange: ClosedRange<Double> {
        switch sport {
        case "Pickleball": return 2.0...3.0
        case "Tennis": return 2.5...4.0
        case "Padel": return 2.2...3.5
        default: return 2.0...3.0
        }
    }

    var minimumSwingThreshold: Double {
        switch sport {
        case "Pickleball": return 1.8
        case "Tennis": return 2.2
        case "Padel": return 2.0
        default: return 1.8
        }
    }

    // Calibration ranges per sport
    var expectedMagnitudeRange: ClosedRange<Double> {
        switch sport {
        case "Pickleball": return 1.6...5.0
        case "Tennis": return 2.0...7.0  // Tennis has wider range
        case "Padel": return 1.8...6.0
        default: return 1.6...5.0
        }
    }

    func classifyShot(
        accel: CMAcceleration,
        rotation: CMRotationRate,
        magnitude: Double,
        rotationMag: Double,
        gyroAngle: Double,
        swingDuration: TimeInterval,
        contextActive: Bool,
        wearingOnSwingingHand: Bool,
        calibration: BackhandCalibration
    ) -> (type: ShotType, isBackhand: Bool) {
        let handMultiplier = wearingOnSwingingHand ? 1.0 : 0.8

        // SMART BACKHAND DETECTION
        // Watch on dominant hand: Y-axis rotation reveals backhand vs forehand
        // Positive Y = pronation (forehand), Negative Y = supination (backhand)
        let isBackhand = detectBackhand(
            rotationY: rotation.y,
            rotationMag: rotationMag,
            magnitude: magnitude,
            swingDuration: swingDuration,
            calibration: calibration
        )

        // Adjust thresholds for non-swinging hand
        let adjustedTouchThreshold = touchShotMagnitudeThreshold * handMultiplier
        let adjustedServeThreshold = serveMagnitudeThreshold * handMultiplier

        // When watch on non-swinging hand, require context to avoid false positives
        if !wearingOnSwingingHand && !contextActive && magnitude < minimumSwingThreshold * 1.2 {
            return (.unknown, isBackhand)
        }

        // SERVE DETECTION
        // Serves have upward acceleration (positive Y) and context usually active
        if contextActive && magnitude > adjustedServeThreshold * 0.8 && accel.y > 0.8 {
            return (.serve, false)  // Serves are neither backhand nor forehand
        } else if accel.y > adjustedServeThreshold && rotationMag > 1.0 {
            return (.serve, false)
        }

        // TOUCH SHOT DETECTION (dink/slice/drop)
        // Characterized by low magnitude AFTER ball impact
        if magnitude <= adjustedTouchThreshold {
            return (.touchShot, isBackhand)
        }

        // OVERHEAD vs POWER SHOT differentiation
        // Use gyroscope angle - overhead has steep angle, powerShot is flatter
        if magnitude > adjustedTouchThreshold {
            // Overhead: steep downward angle + high rotation
            if gyroAngle > powerShotVsOverheadGyroThreshold && rotationMag > 2.0 {
                return (.overhead, false)  // Overheads typically don't have backhand/forehand distinction
            }
            // Also detect overhead from negative Z-axis (downward force)
            if accel.z < -1.0 && rotationMag > (wearingOnSwingingHand ? 2.0 : 1.6) {
                return (.overhead, false)
            }

            // Power Shot: flatter angle + medium-high magnitude + longer duration
            if gyroAngle < powerShotVsOverheadGyroThreshold && magnitude > (minimumSwingThreshold * 1.3) && swingDuration > 0.15 {
                return (.powerShot, isBackhand)
            }
        }

        // VOLLEY DETECTION
        // Volleys are quick reactions with moderate force and low rotation
        if volleyMagnitudeRange.contains(magnitude) && rotationMag < 1.0 && swingDuration < 0.15 {
            return (.volley, isBackhand)
        }

        // Fallback to powerShot for high magnitude shots
        if magnitude > (minimumSwingThreshold * 1.5) {
            return (.powerShot, isBackhand)
        }

        return (.unknown, isBackhand)
    }

    // MARK: - Smart Backhand Detection
    private func detectBackhand(
        rotationY: Double,
        rotationMag: Double,
        magnitude: Double,
        swingDuration: TimeInterval,
        calibration: BackhandCalibration
    ) -> Bool {
        // Use adaptive threshold if calibrated, otherwise use default
        let baseThreshold = calibration.isCalibrated ? calibration.adaptiveThreshold : -0.5

        // CONFIDENCE-BASED DETECTION
        // Higher magnitude shots have more reliable rotation data
        let confidenceMultiplier: Double
        if magnitude > 3.0 {
            // High power shot - very reliable rotation data
            confidenceMultiplier = 1.0
        } else if magnitude > 2.0 {
            // Medium power - fairly reliable
            confidenceMultiplier = 1.2
        } else {
            // Soft shot - less reliable, need stronger signal
            confidenceMultiplier = 1.5
        }

        // SHOT TYPE ADAPTIVE THRESHOLDS
        // Quick volleys have less rotation than full groundstrokes
        let durationAdjustedThreshold: Double
        if swingDuration < 0.15 {
            // Quick volley - subtle rotation, be more sensitive
            durationAdjustedThreshold = baseThreshold * 0.7  // -0.35
        } else if swingDuration > 0.25 {
            // Full groundstroke - clear rotation, can be more strict
            durationAdjustedThreshold = baseThreshold * 1.3  // -0.65
        } else {
            durationAdjustedThreshold = baseThreshold
        }

        // TWO-HANDED BACKHAND ADJUSTMENT
        // Two-handed backhands have lower rotation magnitude but still negative Y-axis
        // If user is detected as two-handed, be more sensitive to lower rotation magnitudes
        let rotationMagThreshold: Double
        if calibration.usesTwoHandedBackhand {
            rotationMagThreshold = 0.2  // More sensitive for two-handed
        } else {
            rotationMagThreshold = 0.3  // Standard for one-handed
        }

        // ROTATION MAGNITUDE FILTER
        // If total rotation is very low, Y-axis direction is unreliable
        if rotationMag < rotationMagThreshold {
            // Very minimal rotation - could be noise, default to forehand
            return false
        }

        // FINAL DECISION with confidence weighting
        let finalThreshold = durationAdjustedThreshold * confidenceMultiplier

        // Additional check: if rotation.y is strongly positive, definitely forehand
        if rotationY > 1.0 {
            return false  // Clear forehand signal
        }

        // DOMINANT HAND ADJUSTMENT
        // If left-handed is detected, patterns may be inverted
        // For now, log this but don't automatically invert (user might have watch on wrong hand)
        // Future enhancement: ask user to confirm hand and auto-adjust

        // Return true if Y-axis rotation is negative beyond threshold
        return rotationY < finalThreshold
    }
}

final class MotionTracker: NSObject, ObservableObject {
    static let shared = MotionTracker()

    @Published var isTracking = false
    @Published var lastShot: DetectedShot?
    @Published var shots: [DetectedShot] = []
    @Published var calibration = UserCalibration()
    @Published var backhandCalibration = BackhandCalibration()
    @Published var currentMagnitude: Double = 0
    @Published var currentSport: String = "Pickleball" {
        didSet {
            // Update cached heuristics when sport changes
            if currentSport != oldValue {
                cachedHeuristics = SportHeuristics(sport: currentSport)
            }
        }
    }
    @AppStorage("wearOnSwingingHand") var watchOnSwingingHand: Bool = true

    private let motionManager = CMMotionManager()
    private var timer: Timer?
    private var recentCandidates: [DetectedShot] = []
    private var lastPointTimestamp: Date?
    private var lastShotTimestamp: Date?

    // Swing tracking state
    private var swingStartTime: Date?
    private var swingPeakMagnitude: Double = 0
    private var swingRotationData: [CMRotationRate] = []

    // Debounce: minimum time between detected shots to prevent duplicates
    private let minimumShotInterval: TimeInterval = 0.3

    // Performance: Cache sport heuristics to avoid recreation on every motion update
    private var cachedHeuristics = SportHeuristics(sport: "Pickleball")
    
    private override init() {
        super.init()
        // 12.5Hz (0.08s) is good balance of accuracy vs battery
        // Higher rates (0.05s/20Hz) improve detection but drain battery faster
        motionManager.deviceMotionUpdateInterval = 0.08
    }
    
    func startTracking() {
        guard !motionManager.isDeviceMotionActive else { return }
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.handleMotion(motion)
        }
        isTracking = true
    }
    
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
        isTracking = false
    }
    
    func resetHistory() {
        shots.removeAll()
        lastShot = nil
    }
    
    private func handleMotion(_ motion: CMDeviceMotion) {
        let manager = GameStateManager.shared
        let accel = motion.userAcceleration
        let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        currentMagnitude = magnitude

        let rotation = motion.rotationRate
        let rotationMag = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)

        // Use cached sport-specific heuristics (updated when sport changes)
        let swingThreshold = cachedHeuristics.minimumSwingThreshold * (watchOnSwingingHand ? 1.0 : 0.8)

        // Track swing start and collect rotation data
        if magnitude > swingThreshold * 0.5 {
            if swingStartTime == nil {
                swingStartTime = Date()
                swingPeakMagnitude = magnitude
                swingRotationData = []
            }
            swingRotationData.append(rotation)
            swingPeakMagnitude = max(swingPeakMagnitude, magnitude)
        }

        // Detect swing peak (shot impact)
        guard magnitude > swingThreshold else {
            // Reset swing if magnitude drops below threshold
            if let start = swingStartTime, Date().timeIntervalSince(start) > 0.5 {
                swingStartTime = nil
                swingRotationData = []
                swingPeakMagnitude = 0
            }
            return
        }

        // Only classify if this is near peak magnitude
        guard magnitude >= swingPeakMagnitude * 0.85 else { return }

        // Debounce: prevent rapid duplicate detections
        if let lastShot = lastShotTimestamp,
           Date().timeIntervalSince(lastShot) < minimumShotInterval {
            return
        }

        // Calculate swing metrics
        let swingDuration = swingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let gyroAngle = calculateGyroAngle(rotationData: swingRotationData)

        // Calculate rally reaction time
        let rallyReactionTime = lastShotTimestamp.map { Date().timeIntervalSince($0) }

        // Use sport-specific classification with adaptive backhand calibration
        let (shotType, isBackhand) = cachedHeuristics.classifyShot(
            accel: accel,
            rotation: rotation,
            magnitude: magnitude,
            rotationMag: rotationMag,
            gyroAngle: gyroAngle,
            swingDuration: swingDuration,
            contextActive: manager.pendingPointWindowActive || manager.serveWindowActive,
            wearingOnSwingingHand: watchOnSwingingHand,
            calibration: backhandCalibration
        )

        // Normalize magnitude using sport-specific calibration
        let normalized = calibration.normalize(magnitude: magnitude, sport: currentSport)
        calibration.record(magnitude: magnitude, sport: currentSport)

        // Calculate confidence in backhand detection
        let backhandConfidence = backhandCalibration.getConfidence(rotationY: rotation.y, magnitude: magnitude)

        // Record shot for adaptive learning (only for non-serves, non-overheads)
        if shotType != .serve && shotType != .overhead {
            backhandCalibration.recordShot(rotationY: rotation.y, isBackhand: isBackhand, confidence: backhandConfidence)
        }

        let detected = DetectedShot(
            type: shotType,
            intensity: normalized,
            absoluteMagnitude: magnitude,
            timestamp: Date(),
            isPointCandidate: shotType == .overhead || shotType == .powerShot || shotType == .serve,
            gyroAngle: gyroAngle,
            swingDuration: swingDuration,
            sport: currentSport,
            rallyReactionTime: rallyReactionTime,
            associatedWithPoint: false,  // Will be updated when score changes
            isBackhand: isBackhand
        )

        lastShot = detected
        lastShotTimestamp = Date()
        shots.insert(detected, at: 0)
        if shots.count > 20 {
            shots.removeLast()
        }

        // Reset swing tracking
        swingStartTime = nil
        swingRotationData = []
        swingPeakMagnitude = 0

        let shouldBufferForAssociation = detected.type == .serve || detected.type == .overhead
        manager.registerSwing(detected, bufferForAssociation: shouldBufferForAssociation)

        if detected.isPointCandidate {
            recentCandidates.insert(detected, at: 0)
            recentCandidates = recentCandidates.filter { Date().timeIntervalSince($0.timestamp) < 5 }
        }
    }

    // Calculate gyroscope angle from rotation data
    // Optimized: single pass through data instead of 3 separate maps
    private func calculateGyroAngle(rotationData: [CMRotationRate]) -> Double {
        guard !rotationData.isEmpty else { return 0 }

        // Single-pass accumulation (more efficient than 3 separate map/reduce)
        var sumX: Double = 0
        var sumY: Double = 0
        var sumZ: Double = 0
        for rotation in rotationData {
            sumX += rotation.x
            sumY += rotation.y
            sumZ += rotation.z
        }

        let count = Double(rotationData.count)
        let avgX = sumX / count
        let avgY = sumY / count
        let avgZ = sumZ / count

        // Convert rotation rates to approximate angle
        // For smash: X rotation (pitch) will be high (overhead motion)
        // For drive: Y/Z rotation (yaw/roll) will dominate (horizontal swing)
        let pitchComponent = abs(avgX)
        let horizontalComponent = sqrt(avgY * avgY + avgZ * avgZ)

        // Return angle in degrees (0-90 range approximation)
        let angle = atan2(pitchComponent, horizontalComponent) * 180 / .pi
        return angle
    }

    // Mark a shot as associated with a point (called when score changes)
    func markLastShotAsPointWinner() {
        if let lastShot = lastShot,
           Date().timeIntervalSince(lastShot.timestamp) < 3.0 {  // Within 3 seconds
            // Create updated shot with associatedWithPoint = true
            let updatedShot = DetectedShot(
                type: lastShot.type,
                intensity: lastShot.intensity,
                absoluteMagnitude: lastShot.absoluteMagnitude,
                timestamp: lastShot.timestamp,
                isPointCandidate: lastShot.isPointCandidate,
                gyroAngle: lastShot.gyroAngle,
                swingDuration: lastShot.swingDuration,
                sport: lastShot.sport,
                rallyReactionTime: lastShot.rallyReactionTime,
                associatedWithPoint: true,
                isBackhand: lastShot.isBackhand
            )
            self.lastShot = updatedShot
            if !shots.isEmpty {
                shots[0] = updatedShot
            }
        }
    }
    
}

struct UserCalibration {
    private var history: [String: [Double]] = [:]  // History per sport
    private(set) var minValue: Double = 1.6
    private(set) var maxValue: Double = 5.0

    mutating func record(magnitude: Double, sport: String) {
        if history[sport] == nil {
            history[sport] = []
        }

        history[sport]?.append(magnitude)
        if let count = history[sport]?.count, count > 200 {
            history[sport]?.removeFirst()
        }

        // Update min/max based on current sport's history
        if let sportHistory = history[sport], sportHistory.count >= 20 {
            let sorted = sportHistory.sorted()
            let minIndex = max(0, Int(Double(sorted.count) * 0.1))
            let maxIndex = min(sorted.count - 1, Int(Double(sorted.count) * 0.9))
            minValue = sorted[minIndex]
            maxValue = sorted[maxIndex]
        } else {
            // Use sport defaults if not enough history
            let heuristics = SportHeuristics(sport: sport)
            minValue = heuristics.expectedMagnitudeRange.lowerBound
            maxValue = heuristics.expectedMagnitudeRange.upperBound
        }
    }

    func normalize(magnitude: Double, sport: String) -> Double {
        // Use current min/max or sport defaults
        guard maxValue > minValue else { return 0 }
        let normalized = (magnitude - minValue) / (maxValue - minValue)
        return max(0, min(1, normalized))
    }
}

// MARK: - Backhand Calibration (Adaptive Learning)
struct BackhandCalibration {
    private var forehandRotations: [Double] = []  // Positive Y rotations
    private var backhandRotations: [Double] = []  // Negative Y rotations

    private(set) var averageForehandRotation: Double = 1.5
    private(set) var averageBackhandRotation: Double = -1.5
    private(set) var adaptiveThreshold: Double = -0.5

    // Dominant hand detection
    private(set) var dominantHand: DominantHand = .right
    private var rotationPolarity: [Double] = []  // Track overall rotation direction

    // Two-handed backhand detection (Tennis)
    private var twoHandedBackhandCount: Int = 0
    private var oneHandedBackhandCount: Int = 0
    private(set) var usesTwoHandedBackhand: Bool = false

    // Track how confident we are in the calibration
    var isCalibrated: Bool {
        forehandRotations.count >= 10 && backhandRotations.count >= 10
    }

    // Show two-handed backhand status once we have enough data
    var showsTwoHandedStatus: Bool {
        (twoHandedBackhandCount + oneHandedBackhandCount) >= 10
    }

    mutating func recordShot(rotationY: Double, isBackhand: Bool, confidence: Double, magnitude: Double = 0, rotationMag: Double = 0) {
        // Only record high-confidence shots for learning
        guard confidence > 0.7 else { return }

        // Track rotation polarity for dominant hand detection
        rotationPolarity.append(rotationY)
        if rotationPolarity.count > 50 {
            rotationPolarity.removeFirst()
            detectDominantHand()
        }

        if isBackhand {
            backhandRotations.append(rotationY)
            if backhandRotations.count > 100 {
                backhandRotations.removeFirst()
            }

            // Detect two-handed backhand (lower rotation magnitude)
            if rotationMag < 0.8 && magnitude > 2.0 {
                twoHandedBackhandCount += 1
            } else {
                oneHandedBackhandCount += 1
            }

            // Update two-handed preference after sufficient data
            if twoHandedBackhandCount + oneHandedBackhandCount >= 20 {
                usesTwoHandedBackhand = Double(twoHandedBackhandCount) > Double(oneHandedBackhandCount) * 1.5
            }
        } else {
            forehandRotations.append(rotationY)
            if forehandRotations.count > 100 {
                forehandRotations.removeFirst()
            }
        }

        // Recalculate adaptive threshold
        updateAdaptiveThreshold()
    }

    private mutating func detectDominantHand() {
        guard rotationPolarity.count >= 30 else { return }

        // Count positive vs negative rotations
        let positiveCount = rotationPolarity.filter { $0 > 0 }.count
        let negativeCount = rotationPolarity.filter { $0 < 0 }.count

        // If rotations are consistently inverted, watch might be on left hand
        if Double(negativeCount) > Double(positiveCount) * 1.5 {
            // More negative rotations = likely left-handed or watch on wrong hand
            dominantHand = .left
        } else if Double(positiveCount) > Double(negativeCount) * 1.5 {
            dominantHand = .right
        } else {
            dominantHand = .unknown
        }
    }

    private mutating func updateAdaptiveThreshold() {
        guard isCalibrated else { return }

        // Calculate average rotations
        averageForehandRotation = forehandRotations.reduce(0, +) / Double(forehandRotations.count)
        averageBackhandRotation = backhandRotations.reduce(0, +) / Double(backhandRotations.count)

        // Set threshold as midpoint between average forehand and backhand
        adaptiveThreshold = (averageForehandRotation + averageBackhandRotation) / 2.0

        // Clamp to reasonable range (-2.0 to 0.0)
        adaptiveThreshold = max(-2.0, min(0.0, adaptiveThreshold))
    }

    func getConfidence(rotationY: Double, magnitude: Double) -> Double {
        // Return confidence score 0.0 to 1.0 for this classification

        // Higher magnitude = more confidence
        let magnitudeConfidence = min(1.0, magnitude / 4.0)

        // Distance from threshold = more confidence
        let distance = abs(rotationY - adaptiveThreshold)
        let thresholdConfidence = min(1.0, distance / 1.5)

        // Combined confidence
        return (magnitudeConfidence + thresholdConfidence) / 2.0
    }
}

struct MotionTrackerView: View {
    @ObservedObject var tracker = MotionTracker.shared
    @AppStorage("wearOnSwingingHand") private var watchOnSwingingHand: Bool = true
    
    var body: some View {
        List {
            Section("Status") {
                Toggle(isOn: Binding(
                    get: { tracker.isTracking },
                    set: { $0 ? tracker.startTracking() : tracker.stopTracking() }
                )) {
                    Text(tracker.isTracking ? "Tracking Enabled" : "Tracking Disabled")
                }
                
                HStack {
                    Text("Current magnitude")
                    Spacer()
                    Text(String(format: "%.2fg", tracker.currentMagnitude))
                        .foregroundColor(.secondary)
                }
                
                Button("Reset History") {
                    tracker.resetHistory()
                }
            }
            
            Section("Onboarding") {
                Toggle("Watch on swinging hand", isOn: $watchOnSwingingHand)
                Text(watchOnSwingingHand ? "Using higher motion sensitivity." : "Relying more on context; reduced false alarms.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            if let shot = tracker.lastShot {
                Section("Last Shot") {
                    HStack {
                        Text(shot.type.icon)
                        Text(shot.displayName)
                        Spacer()
                        Text(shot.intensity.asPercent)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Magnitude")
                        Spacer()
                        Text(String(format: "%.2fg", shot.absoluteMagnitude))
                    }

                    HStack {
                        Text("Time")
                        Spacer()
                        Text(shot.timestamp, style: .time)
                    }
                }
            }

            Section("Recent Shots") {
                if tracker.shots.isEmpty {
                    Text("No swings detected yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(tracker.shots) { shot in
                        HStack {
                            Text(shot.type.icon)
                            Text(shot.displayName)
                            Spacer()
                            Text(shot.intensity.asPercent)
                        }
                    }
                }
            }
            
            Section("Power Calibration") {
                HStack {
                    Text("Min")
                    Spacer()
                    Text(String(format: "%.2f g", tracker.calibration.minValue))
                }
                HStack {
                    Text("Max")
                    Spacer()
                    Text(String(format: "%.2f g", tracker.calibration.maxValue))
                }
            }

            Section("Backhand Detection") {
                HStack {
                    Text("Status")
                    Spacer()
                    if tracker.backhandCalibration.isCalibrated {
                        Text("Calibrated ✓")
                            .foregroundColor(.green)
                    } else {
                        Text("Learning...")
                            .foregroundColor(.orange)
                    }
                }

                // Dominant Hand Detection
                HStack {
                    Text("Dominant Hand")
                    Spacer()
                    switch tracker.backhandCalibration.dominantHand {
                    case .right:
                        Text("Right 🤚")
                            .foregroundColor(.blue)
                    case .left:
                        Text("Left 🤚")
                            .foregroundColor(.purple)
                    case .unknown:
                        Text("Detecting...")
                            .foregroundColor(.secondary)
                    }
                }

                // Two-Handed Backhand (Tennis-specific)
                if tracker.currentSport == "Tennis" && tracker.backhandCalibration.showsTwoHandedStatus {
                    HStack {
                        Text("Backhand Style")
                        Spacer()
                        if tracker.backhandCalibration.usesTwoHandedBackhand {
                            Text("Two-Handed 🎾")
                                .foregroundColor(.green)
                        } else {
                            Text("One-Handed 🎾")
                                .foregroundColor(.blue)
                        }
                    }
                }

                if tracker.backhandCalibration.isCalibrated {
                    HStack {
                        Text("Threshold")
                        Spacer()
                        Text(String(format: "%.2f", tracker.backhandCalibration.adaptiveThreshold))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("FH avg rotation")
                        Spacer()
                        Text(String(format: "%.2f", tracker.backhandCalibration.averageForehandRotation))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("BH avg rotation")
                        Spacer()
                        Text(String(format: "%.2f", tracker.backhandCalibration.averageBackhandRotation))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Play a few points to calibrate backhand detection")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Motion Tracking")
    }
}

private extension Double {
    var asPercent: String {
        String(format: "%.0f%%", self * 100)
    }
}
