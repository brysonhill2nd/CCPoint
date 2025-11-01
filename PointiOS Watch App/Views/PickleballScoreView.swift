//
//  PickleballScoreView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI
import WatchKit
import HealthKit

struct PickleballScoreView: View {
    @StateObject var gameState: GameState
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.scenePhase) var scenePhase

    @State private var showingWinScreen = false
    @State private var navigateToNextGame = false
    @State private var hasBeenSaved = false // ADDED THIS

    // Screen awake management
    @StateObject private var screenAwakeCoordinator = ScreenAwakeCoordinator()

    // UI Layout Constants
    let scoreFontSize: CGFloat = 70
    let gameCountFontSize: CGFloat = 14
    let timerFontSize: CGFloat = 14
    let serviceDotSize: CGFloat = 12

    var body: some View {
        VStack(spacing: 5) {
            // Top Bar: Timer and Game Counts
            HStack {
                Text(gameState.formatTime(gameState.elapsedTime))
                    .font(.system(size: timerFontSize, weight: .semibold))
                    .foregroundColor(.yellow)
                Spacer()
                HStack(spacing: 2) {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: gameCountFontSize * 0.7, height: gameCountFontSize * 0.7)
                    Text("\(gameState.player1GamesWon)")
                        .font(.system(size: gameCountFontSize, weight: .bold))
                }
                .foregroundColor(.red)

                Spacer().frame(width: 15)

                HStack(spacing: 2) {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: gameCountFontSize * 0.7, height: gameCountFontSize * 0.7)
                    Text("\(gameState.player2GamesWon)")
                        .font(.system(size: gameCountFontSize, weight: .bold))
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.top, 5)

            // Main Score Area
            HStack(alignment: .top, spacing: 10) {
                // Player 1 Column
                VStack(alignment: .leading) {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 5)
                    ScoreSideView(
                        score: gameState.player1Score,
                        isServing: gameState.currentServer == .player1,
                        isSecondServerInTeam: gameState.currentServer == .player1 && gameState.isSecondServer,
                        totalServersInTeam: gameState.gameType == .doubles ? 2 : 1,
                        dotSize: serviceDotSize,
                        scoreFontSize: scoreFontSize
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        gameState.recordRallyOutcome(tappedPlayer: .player1)
                        screenAwakeCoordinator.refreshScreenAwakeSession()
                    }
                }

                // Player 2 Column
                VStack(alignment: .trailing) {
                    Text("Opponent")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.trailing, 5)
                    ScoreSideView(
                        score: gameState.player2Score,
                        isServing: gameState.currentServer == .player2,
                        isSecondServerInTeam: gameState.currentServer == .player2 && gameState.isSecondServer,
                        totalServersInTeam: gameState.gameType == .doubles ? 2 : 1,
                        dotSize: serviceDotSize,
                        scoreFontSize: scoreFontSize
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        gameState.recordRallyOutcome(tappedPlayer: .player2)
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
                // UPDATED "End Game" Button Logic
                Button("End Game") {
                    print("🏠 End Game button tapped - Going to Home")
                    gameState.stopTimer()
                    screenAwakeCoordinator.stopScreenAwakeSession()
                    if !hasBeenSaved {
                        historyManager.addGameAndSync(gameState, sportType: "Pickleball")
                        hasBeenSaved = true
                    }
                    navigationManager.navigateToHome()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Undo") {
                    gameState.undoLastAction()
                }
                .disabled(!gameState.canUndo())
            }
        }
        // UPDATED onChange modifier
        .onChange(of: gameState.isGameOver, initial: false) { _, isOver in
            if isOver && !hasBeenSaved {
                showingWinScreen = true
                screenAwakeCoordinator.stopScreenAwakeSession()
                historyManager.addGameAndSync(gameState, sportType: "Pickleball")
                hasBeenSaved = true // Mark as saved
                print("🎯 Game finished - saved to history (once)")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            screenAwakeCoordinator.handleScenePhase(newPhase)
        }
        .sheet(isPresented: $showingWinScreen, onDismiss: handleSheetDismiss) {
            GameEndView(gameState: gameState)
        }
        .navigationDestination(isPresented: $navigateToNextGame) {
            FirstServerView(
                gameType: gameState.gameType,
                initialPlayer1Games: gameState.player1GamesWon,
                initialPlayer2Games: gameState.player2GamesWon
            )
        }
        .onAppear {
            screenAwakeCoordinator.startScreenAwakeSession()
            gameState.startHealthTracking()
        }
        .onDisappear {
            screenAwakeCoordinator.stopScreenAwakeSession()
        }
    }

    private func handleSheetDismiss() {
        if gameState.checkMatchWinCondition() != nil || gameState.settings.matchFormatType == .single {
            print("🏠 Match finished - Going to Home")
            screenAwakeCoordinator.stopScreenAwakeSession()
            navigationManager.navigateToHome()
        } else {
            screenAwakeCoordinator.startScreenAwakeSession()
            navigateToNextGame = true
        }
    }
}

// Simplified ScreenAwakeCoordinator that doesn't create its own workout session
class ScreenAwakeCoordinator: NSObject, ObservableObject {
    private var runtimeSession: WKExtendedRuntimeSession?
    private var isScreenAwakeActive = false

    func startScreenAwakeSession() {
        guard !isScreenAwakeActive else { return }

        print("🔋 Starting screen awake session...")
        stopScreenAwakeSession()

        // Only use Extended Runtime Session
        // Let WatchHealthKitManager handle the workout session
        runtimeSession = WKExtendedRuntimeSession()
        runtimeSession?.delegate = self
        runtimeSession?.start()

        isScreenAwakeActive = true
        print("✅ Screen awake session active")
    }

    func stopScreenAwakeSession() {
        guard isScreenAwakeActive else { return }

        print("🛑 Stopping screen awake session...")

        runtimeSession?.invalidate()
        runtimeSession = nil

        isScreenAwakeActive = false
        print("✅ Screen awake session stopped")
    }

    func refreshScreenAwakeSession() {
        // Don't refresh constantly - the health workout will keep screen awake
        print("🔄 Screen awake refresh skipped - health workout active")
    }

    func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            print("📱 App became active")
            startScreenAwakeSession()
        case .inactive:
            print("📱 App became inactive")
            // Don't stop immediately - let the game finish
        case .background:
            print("📱 App went to background")
            stopScreenAwakeSession()
        @unknown default:
            break
        }
    }
}

// Keep only the WKExtendedRuntimeSessionDelegate extension
extension ScreenAwakeCoordinator: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("🔋 Extended runtime session confirmed started")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("⚠️ Extended runtime session will expire")
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("❌ Extended runtime session invalidated: \(reason)")
    }
}
