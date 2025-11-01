//
//  PadelFirstServerView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//
import SwiftUI

struct PadelFirstServerView: View, Hashable {
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var padelSettings: PadelSettings
    @EnvironmentObject var gameSettings: GameSettings  // Keep this for other purposes if needed
    
    static func == (lhs: PadelFirstServerView, rhs: PadelFirstServerView) -> Bool {
        true
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine("PadelFirstServerView")
    }
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Who serves first?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom)
            
            Button(action: {
                startPadelGame(firstServer: .player1)
            }) {
                VStack {
                    Text("You")
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            
            Button(action: {
                startPadelGame(firstServer: .player2)
            }) {
                VStack {
                    Text("Opponent")
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .navigationTitle("⚡")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func startPadelGame(firstServer: Player) {
        let gameState = PadelGameState(
            firstServer: firstServer,
            settings: padelSettings  // Changed from gameSettings to padelSettings
        )
        navigationManager.navigationPath.append(gameState)
    }
}
