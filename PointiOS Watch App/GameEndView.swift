//
//  GameEndView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI

struct GameEndView: View {
    @ObservedObject var gameState: GameState
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss
    
    @State private var healthData: WorkoutSummary?

    private var winnerText: String {
        if let winner = gameState.winner {
            return winner == .player1 ? "🎉 You Win!" : "😔 You Lost"
        }
        return "Game Over"
    }
    
    private var matchIsOver: Bool {
        gameState.checkMatchWinCondition() != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Winner Display
                Text(winnerText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                // Score Summary
                VStack(spacing: 8) {
                    Text("Final Score")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(gameState.player1Score) - \(gameState.player2Score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    if gameState.player1GamesWon > 0 || gameState.player2GamesWon > 0 {
                        Text("Games: \(gameState.player1GamesWon) - \(gameState.player2GamesWon)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Time: \(gameState.formatTime(gameState.elapsedTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Health Data Section
                if let health = healthData {
                    HStack(spacing: 20) {
                        // Heart Rate
                        VStack(spacing: 4) {
                            Text("❤️")
                                .font(.title2)
                            Text("\(Int(health.averageHeartRate))")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("avg bpm")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Calories
                        VStack(spacing: 4) {
                            Text("🔥")
                                .font(.title2)
                            Text("\(Int(health.totalCalories))")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("calories")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer().frame(height: 20)

                // Action Buttons
                VStack(spacing: 12) {
                    if matchIsOver {
                        Text("🏆 Match Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Button("Go Home") {
                            dismiss()
                            navigationManager.navigateToHome()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                    } else if gameState.settings.matchFormatType != .single {
                        Text("Game \(gameState.player1GamesWon + gameState.player2GamesWon + 1) Complete")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Button("Continue Match") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                        
                        Button("End Match") {
                            dismiss()
                            navigationManager.navigateToHome()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                    } else {
                        Text("🏓 Game Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Button("Go Home") {
                            dismiss()
                            navigationManager.navigateToHome()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            gameState.stopTimer()
            // Retrieve health data
            Task {
                healthData = await gameState.endHealthTracking()
            }
        }
    }
}
