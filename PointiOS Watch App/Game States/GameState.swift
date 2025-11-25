//
//  GameState.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//

import Foundation
import Combine

// GameEvent struct is now in GameEvent.swift - no need to declare here

class GameState: ObservableObject, Identifiable, Hashable {
    let id = UUID()
    let gameType: GameType
    let settings: GameSettings

    // Scores & Game Counts
    @Published var player1Score: Int = 0
    @Published var player2Score: Int = 0
    @Published var player1GamesWon: Int = 0
    @Published var player2GamesWon: Int = 0

    // Serving State
    @Published var currentServer: Player?
    @Published var isSecondServer: Bool = false
    let initialGameServer: Player
    @Published var doublesStartingServerRole: DoublesServerRole?

    // Timer
    @Published var elapsedTime: TimeInterval = 0
    private var timerCancellable: AnyCancellable?
    private var timerStartDate: Date?

    // Game Over State
    @Published var winner: Player? = nil
    var isGameOver: Bool { winner != nil }
    
    // MARK: - Undo Functionality
    @Published var actionHistory: [(player1Score: Int, player2Score: Int, server: Player?, isSecondServer: Bool, winner: Player?, player1GamesWon: Int, player2GamesWon: Int)] = []
    
    // MARK: - Point-by-Point Tracking
    @Published var gameEvents: [GameEvent] = []
    @Published var pendingServeWindow: Date?

    // MARK: - Initializer
    init(
        gameType: GameType,
        firstServer: Player,
        settings: GameSettings,
        initialPlayer1Games: Int = 0,
        initialPlayer2Games: Int = 0,
        doublesStartingServerRole: DoublesServerRole? = nil
    ) {
        self.gameType = gameType
        self.currentServer = firstServer
        self.initialGameServer = firstServer
        self.settings = settings
        self.player1GamesWon = initialPlayer1Games
        self.player2GamesWon = initialPlayer2Games
        self.doublesStartingServerRole = doublesStartingServerRole

        if gameType == .doubles {
            self.isSecondServer = true
        } else {
            self.isSecondServer = false
        }
        pendingServeWindow = Date()
        
        // Add initial 0-0 event
        gameEvents.append(GameEvent(
            timestamp: 0,
            player1Score: 0,
            player2Score: 0,
            scoringPlayer: firstServer, // Just for initialization
            isServePoint: false,
            shotType: nil
        ))

        startTimer()
        GameStateManager.shared.setActiveGame(self)
    }

    deinit {
        stopTimer()
    }

    // MARK: - Hashable Conformance
    static func == (lhs: GameState, rhs: GameState) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Core Game Logic
    func recordRallyOutcome(tappedPlayer: Player) {
        guard winner == nil, let server = currentServer else { return }
        let associatedShot = GameStateManager.shared.resolvePoint()
        
        // Save current state before making changes
        saveStateToHistory()

        if tappedPlayer == server {
            handlePointWonByServingTeam(associatedShot: associatedShot)
        } else {
            handleFaultByServingTeam(associatedShot: associatedShot)
        }
    }

    private func handlePointWonByServingTeam(associatedShot: DetectedShot?) {
        guard winner == nil, let server = currentServer else { return }
        
        // Update score
        if server == .player1 {
            player1Score += 1
        } else {
            player2Score += 1
        }
        
        // Record the event
        let event = GameEvent(
            timestamp: elapsedTime,
            player1Score: player1Score,
            player2Score: player2Score,
            scoringPlayer: server,
            isServePoint: true,
            shotType: associatedShot?.type
        )
        gameEvents.append(event)
        
        print("📊 Point recorded: \(player1Score)-\(player2Score), Server: \(server), Total events: \(gameEvents.count)")

        // Mark the last detected shot as associated with this point
        MotionTracker.shared.markLastShotAsPointWinner()

        checkWinCondition()
        setupServeWindowIfNeeded()
    }

    private func handleFaultByServingTeam(associatedShot: DetectedShot?) {
        guard winner == nil, let server = currentServer else { return }
        
        // In pickleball, when serving team loses rally, NO POINTS are scored
        // Just record who won the rally (for tracking purposes)
        let rallyWinner: Player = (server == .player1) ? .player2 : .player1
        
        // Record the event - NO SCORE CHANGE
        let event = GameEvent(
            timestamp: elapsedTime,
            player1Score: player1Score,  // Score stays the same
            player2Score: player2Score,  // Score stays the same
            scoringPlayer: rallyWinner,   // Track who won the rally
            isServePoint: false,
            shotType: associatedShot?.type
        )
        gameEvents.append(event)
        
        print("📊 Fault recorded: \(player1Score)-\(player2Score), Rally won by: \(rallyWinner), Total events: \(gameEvents.count)")

        // Then handle serve change
        if gameType == .singles {
            performSideOut()
        } else { // Doubles
            if !isSecondServer {
                isSecondServer = true
            } else {
                performSideOut()
            }
        }
        
        // Mark the last detected shot as associated with this point
        MotionTracker.shared.markLastShotAsPointWinner()

        // No checkWinCondition() needed since no points were scored
        setupServeWindowIfNeeded()
    }

    private func performSideOut() {
        guard let server = currentServer else { return }
        currentServer = (server == .player1) ? .player2 : .player1
        isSecondServer = false
        setupServeWindowIfNeeded()
    }
    
    private func setupServeWindowIfNeeded() {
        guard let server = currentServer, server == .player1 else {
            pendingServeWindow = nil
            return
        }
        pendingServeWindow = Date().addingTimeInterval(3)
    }
    
    // MARK: - Undo Methods
    private func saveStateToHistory() {
        actionHistory.append((
            player1Score: player1Score,
            player2Score: player2Score,
            server: currentServer,
            isSecondServer: isSecondServer,
            winner: winner,
            player1GamesWon: player1GamesWon,
            player2GamesWon: player2GamesWon
        ))
        
        // Keep only last 10 actions to prevent memory issues
        if actionHistory.count > 10 {
            actionHistory.removeFirst()
        }
    }
    
    func undoLastAction() {
        guard let lastState = actionHistory.last else { return }
        actionHistory.removeLast()
        
        // Remove the last game event as well
        if gameEvents.count > 1 { // Keep the initial 0-0 event
            gameEvents.removeLast()
        }
        
        // Restore the previous state
        player1Score = lastState.player1Score
        player2Score = lastState.player2Score
        currentServer = lastState.server
        isSecondServer = lastState.isSecondServer
        player1GamesWon = lastState.player1GamesWon
        player2GamesWon = lastState.player2GamesWon
        
        // Handle winner state
        if winner != nil && lastState.winner == nil {
            winner = nil
            // Restart timer if game was ended
            startTimer()
        } else {
            winner = lastState.winner
        }
    }
    
    func canUndo() -> Bool {
        return !actionHistory.isEmpty
    }

    // MARK: - Timer Management
    func startTimer() {
        stopTimer()
        guard winner == nil else { return }
        
        let startDate = Date()
        timerStartDate = startDate
        elapsedTime = 0
        
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.winner == nil else {
                    self?.stopTimer()
                    return
                }
                self.elapsedTime = Date().timeIntervalSince(startDate)
            }
    }

    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Win Condition Logic
    private func checkWinCondition() {
        guard winner == nil else { return }
        guard let scoreToWin = settings.scoreLimit else { return }
        
        let p1 = player1Score
        let p2 = player2Score
        let target = scoreToWin
        
        if settings.winByTwo {
            if (p1 >= target && p1 >= p2 + 2) {
                winner = .player1
                finishGame()
            } else if (p2 >= target && p2 >= p1 + 2) {
                winner = .player2
                finishGame()
            }
        } else {
            if p1 == target {
                winner = .player1
                finishGame()
            } else if p2 == target {
                winner = .player2
                finishGame()
            }
        }
    }

    private func finishGame() {
        stopTimer()
        if winner == .player1 {
            player1GamesWon += 1
        } else {
            player2GamesWon += 1
        }
        
        print("🏆 Game finished with \(gameEvents.count) total events")
    }

    func checkMatchWinCondition() -> Player? {
        guard let gamesNeeded = settings.getGamesNeededToWinMatch() else {
            return (settings.matchFormatType == .single && winner != nil) ? winner : nil
        }
        
        if player1GamesWon >= gamesNeeded { return .player1 }
        else if player2GamesWon >= gamesNeeded { return .player2 }
        return nil
    }

    // MARK: - Reset Logic
    func resetScoreForCurrentGame() {
        // Clear history when resetting
        actionHistory.removeAll()
        
        player1Score = 0
        player2Score = 0
        currentServer = initialGameServer
        winner = nil
        
        // Clear events and add initial 0-0
        gameEvents = [GameEvent(
            timestamp: 0,
            player1Score: 0,
            player2Score: 0,
            scoringPlayer: initialGameServer,
            isServePoint: false,
            shotType: nil
        )]
        
        if gameType == .doubles {
            isSecondServer = true
        } else {
            isSecondServer = false
        }
        
        stopTimer()
        startTimer()
    }

    // MARK: - Formatting Helpers
    func formatTime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: max(0, interval)) ?? "00:00"
    }
    
    // MARK: - Game Insights
    func getInsights() -> GameInsights? {
        guard gameEvents.count > 1 else { return nil }
        
        return GameInsights(
            events: gameEvents,
            finalScore: (player1: player1Score, player2: player2Score),
            winner: winner ?? .player1,
            duration: elapsedTime
        )
    }
}
