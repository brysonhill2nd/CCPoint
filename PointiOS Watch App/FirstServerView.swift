//
//  FirstServerView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI

struct FirstServerView: View {
    @EnvironmentObject var gameSettings: GameSettings
    @EnvironmentObject var navigationManager: NavigationManager
    let gameType: GameType
    let initialPlayer1Games: Int
    let initialPlayer2Games: Int

    // FIXED: Proper initializer that matches the call
    init(gameType: GameType, initialPlayer1Games: Int = 0, initialPlayer2Games: Int = 0) {
        self.gameType = gameType
        self.initialPlayer1Games = initialPlayer1Games
        self.initialPlayer2Games = initialPlayer2Games
    }

    var body: some View {
        VStack(spacing: 25) {
            Text("Who serves first?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom)

            Button(action: {
                startGame(firstServer: .player1)
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
                startGame(firstServer: .player2)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startGame(firstServer: Player) {
        if gameType == .doubles && firstServer == .player1 {
            let view = PickleballDoublesServerRoleView(
                initialPlayer1Games: initialPlayer1Games,
                initialPlayer2Games: initialPlayer2Games
            )
            navigationManager.navigationPath.append(view)
        } else {
            let gameState = GameState(
                gameType: gameType,
                firstServer: firstServer,
                settings: gameSettings,
                initialPlayer1Games: initialPlayer1Games,
                initialPlayer2Games: initialPlayer2Games
            )
            navigationManager.navigationPath.append(gameState)
        }
    }
}
