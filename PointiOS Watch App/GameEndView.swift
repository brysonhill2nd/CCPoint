//
//  GameEndView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//  Updated with Swiss Design System
//
import SwiftUI

struct GameEndView: View {
    @ObservedObject var gameState: GameState
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss

    @State private var healthData: WorkoutSummary?

    private var isWin: Bool {
        gameState.winner == .player1
    }

    private var winnerText: String {
        if gameState.winner != nil {
            return isWin ? "YOU WIN" : "YOU LOST"
        }
        return "GAME OVER"
    }

    private var matchIsOver: Bool {
        gameState.checkMatchWinCondition() != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Winner Display - Swiss style
                VStack(spacing: 8) {
                    Text(winnerText)
                        .font(WatchTypography.monoLabel(14))
                        .tracking(2)
                        .foregroundColor(isWin ? WatchColors.green : WatchColors.loss)

                    // Score
                    Text("\(gameState.player1Score) - \(gameState.player2Score)")
                        .font(WatchTypography.scoreMedium())
                        .foregroundColor(WatchColors.textPrimary)

                    if gameState.player1GamesWon > 0 || gameState.player2GamesWon > 0 {
                        Text("GAMES \(gameState.player1GamesWon) - \(gameState.player2GamesWon)")
                            .font(WatchTypography.monoLabel(10))
                            .foregroundColor(WatchColors.textSecondary)
                    }

                    Text(gameState.formatTime(gameState.elapsedTime))
                        .font(WatchTypography.monoLabel(11))
                        .foregroundColor(WatchColors.textTertiary)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(WatchColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isWin ? WatchColors.green.opacity(0.5) : WatchColors.loss.opacity(0.5), lineWidth: 2)
                )

                // Health Data Section - Swiss style
                if let health = healthData {
                    HStack(spacing: 12) {
                        // Heart Rate
                        VStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(WatchColors.loss)
                            Text("\(Int(health.averageHeartRate))")
                                .font(WatchTypography.headline())
                                .foregroundColor(WatchColors.textPrimary)
                            Text("BPM")
                                .font(WatchTypography.monoLabel(8))
                                .foregroundColor(WatchColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Calories
                        VStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(WatchColors.caution)
                            Text("\(Int(health.totalCalories))")
                                .font(WatchTypography.headline())
                                .foregroundColor(WatchColors.textPrimary)
                            Text("CAL")
                                .font(WatchTypography.monoLabel(8))
                                .foregroundColor(WatchColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Action Buttons - Swiss style
                VStack(spacing: 10) {
                    if matchIsOver {
                        WatchBadge(text: "Match Complete", isWin: true)

                        Button(action: {
                            dismiss()
                            navigationManager.navigateToHome()
                        }) {
                            Text("HOME")
                                .font(WatchTypography.button())
                                .tracking(0.5)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(WatchColors.green)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                    } else if gameState.settings.matchFormatType != .single {
                        Text("GAME \(gameState.player1GamesWon + gameState.player2GamesWon + 1)")
                            .font(WatchTypography.monoLabel(10))
                            .foregroundColor(WatchColors.textSecondary)

                        Button(action: { dismiss() }) {
                            Text("CONTINUE")
                                .font(WatchTypography.button())
                                .tracking(0.5)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(WatchColors.green)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            dismiss()
                            navigationManager.navigateToHome()
                        }) {
                            Text("END MATCH")
                                .font(WatchTypography.button())
                                .tracking(0.5)
                                .foregroundColor(WatchColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(WatchColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(WatchColors.borderSubtle, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                    } else {
                        WatchBadge(text: "Game Complete", isWin: true)

                        Button(action: {
                            dismiss()
                            navigationManager.navigateToHome()
                        }) {
                            Text("HOME")
                                .font(WatchTypography.button())
                                .tracking(0.5)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(WatchColors.green)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            gameState.stopTimer()
            Task {
                if let cached = await HealthSummaryCache.shared.get(gameState.id) {
                    healthData = cached
                } else {
                    healthData = await gameState.endHealthTracking()
                }
            }
        }
    }
}
