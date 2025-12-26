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
        VStack(spacing: 16) {
            Text("WHO SERVES FIRST?")
                .font(WatchTypography.monoLabel(11))
                .tracking(1)
                .foregroundColor(WatchColors.textSecondary)
                .padding(.bottom, 8)

            Button(action: {
                if gameType == .doubles {
                    let serverRoleView = TennisDoublesServerRoleView(gameType: gameType)
                    navigationManager.navigationPath.append(serverRoleView)
                } else {
                    startGame(firstServer: .player1, doublesServerRole: nil)
                }
            }) {
                HStack {
                    Image(systemName: gameType == .doubles ? "person.2.fill" : "person.fill")
                        .font(.system(size: 16))
                    Text(gameType == .doubles ? "YOUR TEAM" : "YOU")
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
                startGame(firstServer: .player2, doublesServerRole: nil)
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

    private func startGame(firstServer: Player, doublesServerRole: DoublesServerRole?) {
        let gameState = TennisGameState(
            gameType: gameType,
            firstServer: firstServer,
            settings: tennisSettings,
            doublesStartingServerRole: doublesServerRole
        )
        navigationManager.navigationPath.append(gameState)
    }
}

extension TennisFirstServerView: Hashable {
    static func == (lhs: TennisFirstServerView, rhs: TennisFirstServerView) -> Bool {
        lhs.gameType == rhs.gameType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(gameType)
    }
}

// MARK: - Second screen for doubles: You or Partner
struct TennisDoublesServerRoleView: View, Hashable {
    @EnvironmentObject var tennisSettings: TennisSettings
    @EnvironmentObject var navigationManager: NavigationManager
    let gameType: GameType

    static func == (lhs: TennisDoublesServerRoleView, rhs: TennisDoublesServerRoleView) -> Bool {
        lhs.gameType == rhs.gameType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(gameType)
        hasher.combine("TennisDoublesServerRoleView")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("WHO ON YOUR TEAM?")
                .font(WatchTypography.monoLabel(11))
                .tracking(1)
                .foregroundColor(WatchColors.textSecondary)

            Text("Choose who starts serving")
                .font(WatchTypography.caption())
                .foregroundColor(WatchColors.textTertiary)
                .padding(.bottom, 8)

            Button(action: {
                startGame(doublesServerRole: .you)
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
                startGame(doublesServerRole: .partner)
            }) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                    Text("PARTNER")
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

    private func startGame(doublesServerRole: DoublesServerRole) {
        let gameState = TennisGameState(
            gameType: gameType,
            firstServer: .player1,
            settings: tennisSettings,
            doublesStartingServerRole: doublesServerRole
        )
        navigationManager.navigationPath.append(gameState)
    }
}
