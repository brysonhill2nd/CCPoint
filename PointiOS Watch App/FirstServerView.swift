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
        VStack(spacing: 16) {
            Text("WHO SERVES FIRST?")
                .font(WatchTypography.monoLabel(11))
                .tracking(1)
                .foregroundColor(WatchColors.textSecondary)
                .padding(.bottom, 8)

            Button(action: {
                startGame(firstServer: .player1)
            }) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                    Text("YOU")
                        .font(WatchTypography.button())
                        .tracking(0.5)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WatchColors.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button(action: {
                startGame(firstServer: .player2)
            }) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                    Text("OPPONENT")
                        .font(WatchTypography.button())
                        .tracking(0.5)
                }
                .foregroundColor(WatchColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WatchColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(WatchColors.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
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
