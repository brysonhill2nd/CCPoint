
import Foundation
import Combine

final class GameStateManager: ObservableObject {
    static let shared = GameStateManager()
    
    @Published var activeGame: GameState? {
        didSet {
            serveTimer?.invalidate()
            pendingPointTimer?.invalidate()
            bufferedShot = nil
            bufferedShotExpiry = nil
            setupServeTimer()
        }
    }
    
    @Published var serveWindowActive: Bool = false
    @Published var pendingPointWindowActive: Bool = false
    
    private var serveTimer: Timer?
    private var pendingPointTimer: Timer?
    private var bufferedShot: DetectedShot?
    private var bufferedShotExpiry: Date?
    
    private let pendingWindowDuration: TimeInterval = 3.0
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func setActiveGame(_ game: GameState) {
        activeGame = game
    }
    
    /// Arms a window when we expect a serve based on state (used by classifiers).
    func armServeWindow(duration: TimeInterval = 3) {
        serveWindowActive = true
        serveTimer?.invalidate()
        serveTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.serveWindowActive = false
        }
    }
    
    func consumePendingServe() {
        serveWindowActive = false
        serveTimer?.invalidate()
    }
    
    /// Open a short window after a swing to give the UI time to log the point.
    func registerSwing(_ shot: DetectedShot, bufferForAssociation: Bool) {
        pendingPointWindowActive = true
        pendingPointTimer?.invalidate()
        pendingPointTimer = Timer.scheduledTimer(withTimeInterval: pendingWindowDuration, repeats: false) { [weak self] _ in
            self?.expirePendingPoint()
        }
        
        guard bufferForAssociation else { return }
        bufferedShot = shot
        bufferedShotExpiry = Date().addingTimeInterval(pendingWindowDuration)
    }
    
    /// Close the pending window when the score is recorded and return the swing if still fresh.
    @discardableResult
    func resolvePoint(at date: Date = Date()) -> DetectedShot? {
        pendingPointTimer?.invalidate()
        pendingPointWindowActive = false
        defer {
            bufferedShot = nil
            bufferedShotExpiry = nil
        }
        
        guard
            let shot = bufferedShot,
            let expiry = bufferedShotExpiry,
            date <= expiry
        else { return nil }
        
        return shot
    }
    
    private func expirePendingPoint() {
        pendingPointWindowActive = false
        bufferedShot = nil
        bufferedShotExpiry = nil
    }
    
    private func setupServeTimer() {
        serveWindowActive = false
        pendingPointWindowActive = false
        bufferedShot = nil
        bufferedShotExpiry = nil
    }
}
