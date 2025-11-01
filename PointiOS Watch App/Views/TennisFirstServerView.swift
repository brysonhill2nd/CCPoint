///
//  TennisFirstServerView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//
import SwiftUI

struct TennisFirstServerView: View {
    @EnvironmentObject var tennisSettings: TennisSettings
    @EnvironmentObject var navigationManager: NavigationManager
    let gameType: GameType

    var body: some View {
        VStack(spacing: 25) {
            Text("Who serves first?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom)

            Button(action: {
                let gameState = TennisGameState(
                    gameType: gameType,
                    firstServer: .player1,
                    settings: tennisSettings
                )
                navigationManager.navigationPath.append(gameState)
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
                let gameState = TennisGameState(
                    gameType: gameType,
                    firstServer: .player2,
                    settings: tennisSettings
                )
                navigationManager.navigationPath.append(gameState)
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
}

// If needed, you can add this navigation destination
extension TennisFirstServerView: Hashable {
    static func == (lhs: TennisFirstServerView, rhs: TennisFirstServerView) -> Bool {
        lhs.gameType == rhs.gameType
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(gameType)
    }
}
