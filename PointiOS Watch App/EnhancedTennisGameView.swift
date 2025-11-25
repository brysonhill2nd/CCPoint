//
//  EnhancedTennisGameView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI
import WatchKit
import HealthKit

struct EnhancedTennisGameView: View {
    @ObservedObject var gameState: TennisGameState
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    
    @State private var showingWinScreen = false
    @State private var showTiebreakBanner = false
    @State private var showGoldenPointBanner = false
    
    // Screen awake management
    @StateObject private var screenAwakeCoordinator = TennisScreenAwakeCoordinator()
    
    var body: some View {
        VStack(spacing: 5) {
            // Top banner section
            TimerBannerView(
                elapsedTime: gameState.elapsedTime,
                showTiebreakBanner: showTiebreakBanner,
                showGoldenPointBanner: showGoldenPointBanner,
                formatTime: gameState.formatTime
            )
            
            // Score columns section
            ScoreColumnsView(
                gameState: gameState,
                onPlayer1Tap: {
                    gameState.recordPoint(for: .player1)
                    screenAwakeCoordinator.refreshScreenAwakeSession()
                },
                onPlayer2Tap: {
                    gameState.recordPoint(for: .player2)
                    screenAwakeCoordinator.refreshScreenAwakeSession()
                }
            )
            
            Spacer()
        }
        .padding(.top, 20)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    endGame()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    gameState.undoLastAction()
                }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(gameState.canUndo() ? .orange : .gray)
                }
                .disabled(!gameState.canUndo())
            }
        }
        .onChange(of: gameState.isInTiebreak) { _, isTiebreak in
            handleTiebreakChange(isTiebreak)
        }
        .onChange(of: gameState.player1Score) { _, _ in
            checkForGoldenPoint()
        }
        .onChange(of: gameState.player2Score) { _, _ in
            checkForGoldenPoint()
        }
        .onChange(of: gameState.player1SetsWon) { _, _ in
            checkSetWon()
        }
        .onChange(of: gameState.player2SetsWon) { _, _ in
            checkSetWon()
        }
        .onChange(of: gameState.matchWinner) { _, winner in
            handleMatchWinner(winner)
        }
        .onChange(of: scenePhase) { _, newPhase in
            screenAwakeCoordinator.handleScenePhase(newPhase)
        }
        .sheet(isPresented: $showingWinScreen) {
            TennisGameEndView(gameState: gameState)
        }
        .onAppear {
            screenAwakeCoordinator.startScreenAwakeSession()
            MotionTracker.shared.currentSport = "Tennis"
            MotionTracker.shared.startTracking()
        }
        .onDisappear {
            screenAwakeCoordinator.stopScreenAwakeSession()
            MotionTracker.shared.stopTracking()
        }
    }
    
    // MARK: - Helper Methods
    
    private func endGame() {
        gameState.stopTimer()
        screenAwakeCoordinator.stopScreenAwakeSession()
        historyManager.addTennisGame(gameState)
        dismiss()
        navigationManager.navigateToHome()
    }
    
    private func handleTiebreakChange(_ isTiebreak: Bool) {
        if isTiebreak {
            withAnimation {
                showTiebreakBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showTiebreakBanner = false
                }
            }
        }
    }
    
    private func checkSetWon() {
        if !gameState.isMatchOver {
            showingWinScreen = true
        }
    }
    
    private func handleMatchWinner(_ winner: Player?) {
        if winner != nil {
            showingWinScreen = true
            screenAwakeCoordinator.stopScreenAwakeSession()
            historyManager.addTennisGame(gameState)
        }
    }
    
    private func checkForGoldenPoint() {
        if gameState.settings.goldenPoint &&
           gameState.player1Score >= 3 &&
           gameState.player2Score >= 3 &&
           gameState.player1Score == gameState.player2Score {
            withAnimation {
                showGoldenPointBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showGoldenPointBanner = false
                }
            }
        }
    }
}

// MARK: - Timer Banner View Component
struct TimerBannerView: View {
    let elapsedTime: TimeInterval
    let showTiebreakBanner: Bool
    let showGoldenPointBanner: Bool
    let formatTime: (TimeInterval) -> String
    
    var body: some View {
        ZStack {
            Text(formatTime(elapsedTime))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.yellow)
                .padding(.horizontal)
            
            if showTiebreakBanner {
                TiebreakBanner()
                    .transition(.scale.combined(with: .opacity))
            }
            
            if showGoldenPointBanner {
                GoldenPointBanner()
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Banner Components
struct TiebreakBanner: View {
    var body: some View {
        HStack {
            Text("TIEBREAK • FIRST TO 7")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.yellow)
                .cornerRadius(10)
        }
    }
}

struct GoldenPointBanner: View {
    var body: some View {
        HStack {
            Text("GOLDEN POINT")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange)
                .cornerRadius(10)
        }
    }
}

// MARK: - Score Columns View Component
struct ScoreColumnsView: View {
    @ObservedObject var gameState: TennisGameState
    let onPlayer1Tap: () -> Void
    let onPlayer2Tap: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Player 1 Column
            PlayerScoreColumn(
                title: "You",
                score: player1ScoreDisplay,
                setsWon: gameState.player1SetsWon,
                gamesWon: gameState.player1GamesWon,
                isServing: gameState.currentServer == .player1,
                isSecondServer: gameState.currentServer == .player1 && gameState.isSecondServer,
                totalServersInTeam: gameState.gameType == .doubles ? 2 : 1,
                playerColor: .red,
                onTap: onPlayer1Tap
            )
            
            // Player 2 Column
            PlayerScoreColumn(
                title: "Opponent",
                score: player2ScoreDisplay,
                setsWon: gameState.player2SetsWon,
                gamesWon: gameState.player2GamesWon,
                isServing: gameState.currentServer == .player2,
                isSecondServer: gameState.currentServer == .player2 && gameState.isSecondServer,
                totalServersInTeam: gameState.gameType == .doubles ? 2 : 1,
                playerColor: .blue,
                onTap: onPlayer2Tap
            )
        }
        .padding(.horizontal, 5)
    }
    
    private var player1ScoreDisplay: String {
        gameState.settings.formatScore(
            gameState.player1Score,
            opponentPoints: gameState.player2Score,
            isInTiebreak: gameState.isInTiebreak
        )
    }
    
    private var player2ScoreDisplay: String {
        gameState.settings.formatScore(
            gameState.player2Score,
            opponentPoints: gameState.player1Score,
            isInTiebreak: gameState.isInTiebreak
        )
    }
}

// MARK: - Player Score Column Component
struct PlayerScoreColumn: View {
    let title: String
    let score: String
    let setsWon: Int
    let gamesWon: Int
    let isServing: Bool
    let isSecondServer: Bool
    let totalServersInTeam: Int
    let playerColor: Color
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .center) {
            Text(title)
                .font(.caption)
                .foregroundColor(playerColor)
                .padding(.bottom, 5)
            
            TennisScoreSideView(
                score: score,
                setsWon: setsWon,
                gamesWon: gamesWon,
                isServing: isServing,
                isSecondServer: isSecondServer,
                totalServersInTeam: totalServersInTeam,
                playerColor: playerColor
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}

// MARK: - Tennis Screen Awake Coordinator Class
class TennisScreenAwakeCoordinator: NSObject, ObservableObject {
    private var runtimeSession: WKExtendedRuntimeSession?
    private var workoutSession: HKWorkoutSession?
    private var healthStore = HKHealthStore()
    private var isScreenAwakeActive = false
    
    func startScreenAwakeSession() {
        guard !isScreenAwakeActive else { return }
        
        stopScreenAwakeSession()
        
        // Extended Runtime Session
        runtimeSession = WKExtendedRuntimeSession()
        runtimeSession?.delegate = self
        runtimeSession?.start()
        
        // Workout Session (more aggressive)
        if HKHealthStore.isHealthDataAvailable() {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .tennis
            configuration.locationType = .outdoor
            
            do {
                workoutSession = try HKWorkoutSession(
                    healthStore: healthStore,
                    configuration: configuration
                )
                workoutSession?.delegate = self
                workoutSession?.startActivity(with: Date())
            } catch {
                print("Failed to start workout session: \(error.localizedDescription)")
            }
        }
        
        isScreenAwakeActive = true
    }
    
    func stopScreenAwakeSession() {
        guard isScreenAwakeActive else { return }
        
        runtimeSession?.invalidate()
        runtimeSession = nil
        
        workoutSession?.end()
        workoutSession = nil
        
        isScreenAwakeActive = false
    }
    
    func refreshScreenAwakeSession() {
        if isScreenAwakeActive {
            stopScreenAwakeSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startScreenAwakeSession()
            }
        }
    }

    func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            startScreenAwakeSession()
        case .inactive:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.stopScreenAwakeSession()
            }
        case .background:
            stopScreenAwakeSession()
        @unknown default:
            break
        }
    }
}

// MARK: - Screen Awake Delegates
extension TennisScreenAwakeCoordinator: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        refreshScreenAwakeSession()
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {}
}

extension TennisScreenAwakeCoordinator: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}
