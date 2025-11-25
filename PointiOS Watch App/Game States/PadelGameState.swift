//
//  PadelGameState.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//

import Foundation
import Combine

class PadelGameState: ObservableObject, Identifiable, Hashable {
    let id = UUID()
    let settings: PadelSettings

    // Scores & Counts
    @Published var player1Score: Int = 0
    @Published var player2Score: Int = 0
    @Published var player1GamesWon: Int = 0
    @Published var player2GamesWon: Int = 0
    @Published var player1SetsWon: Int = 0
    @Published var player2SetsWon: Int = 0

    // Serving State - Only one dot active initially
    @Published var currentServer: Player
    @Published var isSecondServer: Bool = false
    
    // Game State
    @Published var isInTiebreak: Bool = false
    @Published var gameWinner: Player? = nil
    @Published var matchWinner: Player? = nil
    @Published var lastSetScore: (player1: Int, player2: Int)? = nil // Store last set's final score
    @Published var tiebreakPointsPlayed: Int = 0 // Track points for serving rotation
    
    // Store complete match history
    @Published var setHistory: [(player1Games: Int, player2Games: Int, tiebreakScore: (player1: Int, player2: Int)?)] = []
    private var tiebreakScore: (player1: Int, player2: Int)? = nil

    // Timer
    @Published var elapsedTime: TimeInterval = 0
    private var timerCancellable: AnyCancellable?
    private var timerStartDate: Date?
    private var totalElapsedTime: TimeInterval = 0
    
    // MARK: - Point-by-Point Tracking
    @Published var gameEvents: [GameEvent] = []
    
    // Undo system
    private var actionHistory: [GameAction] = []
    private let maxHistorySize = 10

    var isGameOver: Bool { gameWinner != nil }
    var isMatchOver: Bool { matchWinner != nil }

    init(firstServer: Player, settings: PadelSettings) {
        self.currentServer = firstServer
        self.settings = settings
        
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
    }

    deinit {
        stopTimer()
    }

    // MARK: - Hashable Conformance
    static func == (lhs: PadelGameState, rhs: PadelGameState) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Core Game Logic - Simple point scoring (no serving restrictions during rallies)
    func recordPoint(for player: Player) {
        let associatedShot = GameStateManager.shared.resolvePoint()
        recordAction(.point(player: player))
        
        if player == .player1 {
            player1Score += 1
        } else {
            player2Score += 1
        }
        
        // Record the event
        let event = GameEvent(
            timestamp: elapsedTime,
            player1Score: player1Score,
            player2Score: player2Score,
            scoringPlayer: player,
            isServePoint: player == currentServer,
            shotType: associatedShot?.type
        )
        gameEvents.append(event)

        // Mark the last detected shot as associated with this point
        MotionTracker.shared.markLastShotAsPointWinner()

        if isInTiebreak {
            tiebreakPointsPlayed += 1
            updateTiebreakServer()
        }
        
        checkGameWinCondition()
    }
    
    private func updateTiebreakServer() {
        // In tiebreak:
        // - First player serves 1 point
        // - Then alternate every 2 points
        if tiebreakPointsPlayed == 1 {
            // After first point, switch to other player
            currentServer = (currentServer == .player1) ? .player2 : .player1
            isSecondServer = false
        } else if tiebreakPointsPlayed > 1 && (tiebreakPointsPlayed - 1) % 2 == 0 {
            // Switch server every 2 points after the first
            currentServer = (currentServer == .player1) ? .player2 : .player1
            isSecondServer = false
        }
    }
    
    private func checkGameWinCondition() {
        let p1 = player1Score
        let p2 = player2Score
        
        if isInTiebreak {
            // Tiebreak: first to 7, win by 2
            if (p1 >= 7 && p1 >= p2 + 2) || (p2 >= 7 && p2 >= p1 + 2) {
                // Store the tiebreak score before finishing
                tiebreakScore = (player1: p1, player2: p2)
                // Tiebreak winner wins the set
                finishTiebreakAndSet(winner: p1 > p2 ? .player1 : .player2)
            }
        } else {
            // Regular game logic
            let atDeuce = p1 >= 3 && p2 >= 3 && p1 == p2
            
            if settings.goldenPoint && atDeuce {
                // Golden point: next point wins (sudden death at deuce)
                return
            } else if settings.goldenPoint && p1 >= 3 && p2 >= 3 && p1 != p2 {
                // Someone just won the golden point
                finishGame(winner: p1 > p2 ? .player1 : .player2)
            } else {
                // Traditional scoring or not at deuce yet
                if p1 >= 4 && p1 >= p2 + 2 {
                    finishGame(winner: .player1)
                } else if p2 >= 4 && p2 >= p1 + 2 {
                    finishGame(winner: .player2)
                }
            }
        }
    }
    
    private func finishTiebreakAndSet(winner: Player) {
        // The set was 6-6, and now someone won the tiebreak
        if winner == .player1 {
            // Player 1 wins the tiebreak, so they win the set 7-6
            lastSetScore = (player1: 7, player2: 6)
            player1SetsWon += 1
        } else {
            // Player 2 wins the tiebreak, so they win the set 6-7
            lastSetScore = (player1: 6, player2: 7)
            player2SetsWon += 1
        }
        
        // Add to set history
        let setScore = (
            player1Games: winner == .player1 ? 7 : 6,
            player2Games: winner == .player2 ? 7 : 6,
            tiebreakScore: tiebreakScore
        )
        setHistory.append(setScore)
        
        // Reset tiebreak state
        isInTiebreak = false
        tiebreakPointsPlayed = 0
        tiebreakScore = nil
        
        checkMatchWinCondition()
        
        if !isMatchOver {
            startNewSet()
        }
    }
    
    private func finishGame(winner: Player) {
        gameWinner = winner
        
        if winner == .player1 {
            player1GamesWon += 1
        } else {
            player2GamesWon += 1
        }
        
        checkSetWinCondition()
        
        // Start new game immediately if match/set continues
        if !isMatchOver && !isSetJustWon() {
            startNewGame()
        }
    }
    
    private func isSetJustWon() -> Bool {
        let p1Games = player1GamesWon
        let p2Games = player2GamesWon
        return (p1Games >= 6 && p1Games >= p2Games + 2) ||
               (p2Games >= 6 && p2Games >= p1Games + 2)
    }
    
    private func checkSetWinCondition() {
        let p1Games = player1GamesWon
        let p2Games = player2GamesWon
        
        // Check if tiebreak needed
        if p1Games == 6 && p2Games == 6 && !isInTiebreak {
            startTiebreak()
            return
        }
        
        // Check set win
        if (p1Games >= 6 && p1Games >= p2Games + 2) {
            finishSet(winner: .player1)
        } else if (p2Games >= 6 && p2Games >= p1Games + 2) {
            finishSet(winner: .player2)
        }
    }
    
    private func startTiebreak() {
        isInTiebreak = true
        player1Score = 0
        player2Score = 0
        gameWinner = nil
        tiebreakPointsPlayed = 0
        
        // The player who would have served game 13 serves first in tiebreak
        // This is already set by the normal rotation
    }
    
    private func finishSet(winner: Player) {
        // Store the final score of this set before resetting
        lastSetScore = (player1: player1GamesWon, player2: player2GamesWon)
        
        // Add to set history
        let setScore = (
            player1Games: player1GamesWon,
            player2Games: player2GamesWon,
            tiebreakScore: nil as (player1: Int, player2: Int)?
        )
        setHistory.append(setScore)
        
        if winner == .player1 {
            player1SetsWon += 1
        } else {
            player2SetsWon += 1
        }
        
        checkMatchWinCondition()
        
        if !isMatchOver {
            startNewSet()
        }
    }
    
    private func checkMatchWinCondition() {
        // Use PadelSettings for match format
        guard let setsNeeded = settings.getGamesNeededToWinMatch() else {
            // Unlimited format - no automatic win
            return
        }
        
        if player1SetsWon >= setsNeeded {
            matchWinner = .player1
            stopTimer()
        } else if player2SetsWon >= setsNeeded {
            matchWinner = .player2
            stopTimer()
        }
    }
    
    private func startNewSet() {
        player1GamesWon = 0
        player2GamesWon = 0
        isInTiebreak = false
        startNewGame()
    }
    
    func startNewGame() {
        player1Score = 0
        player2Score = 0
        gameWinner = nil
        
        // Padel always has doubles serving pattern
        // Calculate total games played in this set
        let totalGames = player1GamesWon + player2GamesWon
        
        // Serving pattern in doubles:
        // Games 0,1: First servers of each team
        // Games 2,3: Second servers of each team
        // Then repeat...
        let cyclePosition = totalGames % 4
        
        switch cyclePosition {
        case 0: // Team A, first server
            currentServer = .player1
            isSecondServer = false
        case 1: // Team B, first server
            currentServer = .player2
            isSecondServer = false
        case 2: // Team A, second server
            currentServer = .player1
            isSecondServer = true
        case 3: // Team B, second server
            currentServer = .player2
            isSecondServer = true
        default:
            break
        }
        
        // Don't restart timer - it continues for the entire match
        // Timer is only stopped when match is over
    }

    // MARK: - Timer Management
    private func startTimer() {
        stopTimer()
        let startDate = Date()
        timerStartDate = startDate
        
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isMatchOver else {
                    self?.stopTimer()
                    return
                }
                self.elapsedTime = self.totalElapsedTime + Date().timeIntervalSince(startDate)
            }
    }
    
    func stopTimer() {
        if let startDate = timerStartDate {
            totalElapsedTime += Date().timeIntervalSince(startDate)
        }
        timerCancellable?.cancel()
        timerCancellable = nil
        timerStartDate = nil
    }
    
    // MARK: - Undo System
    private func recordAction(_ action: GameAction) {
        actionHistory.append(action)
        if actionHistory.count > maxHistorySize {
            actionHistory.removeFirst()
        }
    }
    
    func undoLastAction() {
        guard !actionHistory.isEmpty else { return }
        
        let lastAction = actionHistory.removeLast()
        
        // Remove the last game event as well
        if gameEvents.count > 1 { // Keep the initial 0-0 event
            gameEvents.removeLast()
        }
        
        switch lastAction {
        case .point(let player):
            if player == .player1 && player1Score > 0 {
                player1Score -= 1
            } else if player == .player2 && player2Score > 0 {
                player2Score -= 1
            }
            
            // Handle tiebreak undo
            if isInTiebreak && tiebreakPointsPlayed > 0 {
                tiebreakPointsPlayed -= 1
                // TODO: Restore previous server state
            }
            
            // Reset game winner if it was set
            if gameWinner != nil {
                gameWinner = nil
            }
        default:
            break
        }
    }
    
    func canUndo() -> Bool {
        return !actionHistory.isEmpty
    }
    
    func getUndoDescription() -> String? {
        guard let lastAction = actionHistory.last else { return nil }
        
        switch lastAction {
        case .point(let player):
            return "Undo point for \(player == .player1 ? "You" : "Opponent")"
        default:
            return "Undo last action"
        }
    }
    
    // MARK: - History Helper Methods
    func getMatchScoreSummary() -> String {
        var summary = ""
        for (index, set) in setHistory.enumerated() {
            if index > 0 { summary += ", " }
            summary += "\(set.player1Games)-\(set.player2Games)"
            if let tb = set.tiebreakScore {
                summary += " (\(tb.player1)-\(tb.player2))"
            }
        }
        
        // Add current set if in progress
        if !isMatchOver && (player1GamesWon > 0 || player2GamesWon > 0) {
            if !summary.isEmpty { summary += ", " }
            summary += "\(player1GamesWon)-\(player2GamesWon)"
            if isInTiebreak {
                summary += " (\(player1Score)-\(player2Score))"
            }
        }
        
        return summary
    }
    
    // MARK: - Game Insights
    func getInsights() -> GameInsights? {
        guard gameEvents.count > 1 else { return nil }
        
        return GameInsights(
            events: gameEvents,
            finalScore: (player1: player1Score, player2: player2Score),
            winner: matchWinner ?? .player1,
            duration: elapsedTime
        )
    }
    
    // MARK: - Utility Methods
    func formatTime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: max(0, interval)) ?? "00:00"
    }
}
