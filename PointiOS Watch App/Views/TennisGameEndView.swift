//
//  TennisGameEndView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//
import SwiftUI

struct TennisGameEndView: View {
    @ObservedObject var gameState: TennisGameState
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss

    private var isMatchOver: Bool {
        gameState.matchWinner != nil
    }

    private var winnerText: String {
        if let winner = gameState.matchWinner {
            return winner == .player1 ? "🎉 You Win!" : "😔 You Lost"
        } else {
            // Set ended - check who won THIS set using lastSetScore
            if let lastScore = gameState.lastSetScore {
                let setWinner = lastScore.player1 > lastScore.player2 ? Player.player1 : Player.player2
                return setWinner == .player1 ? "Set Won!" : "Set Lost!"
            }
            return "Set Complete"
        }
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
                    Text("Set Complete")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Show the last set score
                    if let lastScore = gameState.lastSetScore {
                        Text("\(lastScore.player1) - \(lastScore.player2)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    
                    Text("Sets: \(gameState.player1SetsWon) - \(gameState.player2SetsWon)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Time: \(gameState.formatTime(gameState.elapsedTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                Spacer().frame(height: 20)

                // Action Buttons
                VStack(spacing: 12) {
                    if isMatchOver {
                        Text("🏆 Match Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Button("Go Home") {
                            dismiss()
                            navigationManager.navigateToHome()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                    } else {
                        Text("Set \(gameState.player1SetsWon + gameState.player2SetsWon) Complete")
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
                    }
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            gameState.stopTimer()
        }
    }
}
