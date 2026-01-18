//
//  EnhancedPadelGameView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//

import SwiftUI
import WatchKit

struct EnhancedPadelGameView: View {
    @ObservedObject var gameState: PadelGameState
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase

    @State private var showingWinScreen = false
    @State private var showTiebreakBanner = false
    @State private var showGoldenPointBanner = false

    // Screen awake management
    @StateObject private var screenAwakeCoordinator = PadelScreenAwakeCoordinator()

    // UI Layout Constants - matching Pickleball
    let scoreFontSize: CGFloat = 70
    let gameCountFontSize: CGFloat = 14
    let timerFontSize: CGFloat = 14
    let serviceDotSize: CGFloat = 12

    var body: some View {
        VStack(spacing: 5) {
            // Top Bar: Timer and Set/Game Counts - Swiss style (matching Pickleball)
            HStack {
                // Timer
                Text(gameState.formatTime(gameState.elapsedTime))
                    .font(WatchTypography.monoLabel(timerFontSize))
                    .foregroundColor(WatchColors.textSecondary)

                Spacer()

                // Set and game counts
                HStack(spacing: 12) {
                    // Player 1 (You)
                    HStack(spacing: 3) {
                        Circle()
                            .fill(WatchColors.green)
                            .frame(width: 8, height: 8)
                        Text("\(gameState.player1SetsWon)-\(gameState.player1GamesWon)")
                            .font(WatchTypography.monoLabel(gameCountFontSize))
                            .foregroundColor(WatchColors.green)
                    }

                    // Player 2 (Opponent)
                    HStack(spacing: 3) {
                        Circle()
                            .fill(WatchColors.textTertiary)
                            .frame(width: 8, height: 8)
                        Text("\(gameState.player2SetsWon)-\(gameState.player2GamesWon)")
                            .font(WatchTypography.monoLabel(gameCountFontSize))
                            .foregroundColor(WatchColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 5)

            // Tiebreak/Golden Point banners
            if showTiebreakBanner {
                PadelTiebreakBanner()
                    .transition(.scale.combined(with: .opacity))
            }
            if showGoldenPointBanner {
                PadelGoldenPointBanner()
                    .transition(.scale.combined(with: .opacity))
            }

            // Main Score Area - Swiss style (matching Pickleball)
            HStack(alignment: .top, spacing: 10) {
                // Player 1 Column (You)
                VStack(alignment: .leading) {
                    Text("YOU")
                        .font(WatchTypography.monoLabel(9))
                        .foregroundColor(WatchColors.green)
                        .padding(.leading, 5)
                    PadelScoreSideView(
                        score: player1ScoreDisplay,
                        setsWon: gameState.player1SetsWon,
                        gamesWon: gameState.player1GamesWon,
                        isServing: gameState.currentServer == .player1,
                        isSecondServer: gameState.currentServer == .player1 && gameState.isSecondServer,
                        playerColor: WatchColors.green
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        gameState.recordPoint(for: .player1)
                        screenAwakeCoordinator.refreshScreenAwakeSession()
                    }
                }

                // Player 2 Column (Opponent)
                VStack(alignment: .trailing) {
                    Text("OPP")
                        .font(WatchTypography.monoLabel(9))
                        .foregroundColor(WatchColors.textTertiary)
                        .padding(.trailing, 5)
                    PadelScoreSideView(
                        score: player2ScoreDisplay,
                        setsWon: gameState.player2SetsWon,
                        gamesWon: gameState.player2GamesWon,
                        isServing: gameState.currentServer == .player2,
                        isSecondServer: gameState.currentServer == .player2 && gameState.isSecondServer,
                        playerColor: WatchColors.textTertiary
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        gameState.recordPoint(for: .player2)
                        screenAwakeCoordinator.refreshScreenAwakeSession()
                    }
                }
            }
            .padding(.horizontal, 5)

            Spacer()
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    endGame()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(WatchColors.loss)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    gameState.undoLastAction()
                }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(gameState.canUndo() ? WatchColors.caution : WatchColors.buttonDisabled)
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
            PadelGameEndView(gameState: gameState)
        }
        .onAppear {
            screenAwakeCoordinator.startScreenAwakeSession()
            gameState.startHealthTracking()
        }
        .onDisappear {
            screenAwakeCoordinator.stopScreenAwakeSession()
        }
    }
    
    // MARK: - Helper Methods
    
    private func endGame() {
        gameState.stopTimer()
        screenAwakeCoordinator.stopScreenAwakeSession()
        historyManager.addPadelGame(gameState)
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
            historyManager.addPadelGame(gameState)
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

    // MARK: - Score Display Helpers
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

// MARK: - Banner Components (Swiss Style)
struct PadelTiebreakBanner: View {
    var body: some View {
        Text("TIEBREAK")
            .font(WatchTypography.monoLabel(10))
            .foregroundColor(WatchColors.background)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(WatchColors.caution)
            .cornerRadius(8)
    }
}

struct PadelGoldenPointBanner: View {
    var body: some View {
        Text("GOLDEN POINT")
            .font(WatchTypography.monoLabel(10))
            .foregroundColor(WatchColors.background)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(WatchColors.green)
            .cornerRadius(8)
    }
}

// MARK: - Padel Screen Awake Coordinator Class
// Note: Screen stays awake via WatchHealthKitManager's workout session
// This coordinator only handles the extended runtime session for extra reliability
class PadelScreenAwakeCoordinator: NSObject, ObservableObject {
    private var runtimeSession: WKExtendedRuntimeSession?
    private var isScreenAwakeActive = false

    func startScreenAwakeSession() {
        guard !isScreenAwakeActive else { return }

        stopScreenAwakeSession()

        // Extended Runtime Session only - workout is handled by WatchHealthKitManager
        runtimeSession = WKExtendedRuntimeSession()
        runtimeSession?.delegate = self
        runtimeSession?.start()

        isScreenAwakeActive = true
    }

    func stopScreenAwakeSession() {
        guard isScreenAwakeActive else { return }

        runtimeSession?.invalidate()
        runtimeSession = nil

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
extension PadelScreenAwakeCoordinator: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        refreshScreenAwakeSession()
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {}
}
