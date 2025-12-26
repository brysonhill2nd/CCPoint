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

    static func == (lhs: PadelFirstServerView, rhs: PadelFirstServerView) -> Bool {
        true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine("PadelFirstServerView")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("WHO SERVES FIRST?")
                .font(WatchTypography.monoLabel(11))
                .tracking(1)
                .foregroundColor(WatchColors.textSecondary)
                .padding(.bottom, 8)

            Button(action: {
                navigationManager.navigationPath.append(PadelDoublesServerRoleView())
            }) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                    Text("YOUR TEAM")
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
                startPadelGame(firstServer: .player2, doublesServerRole: nil)
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

    private func startPadelGame(firstServer: Player, doublesServerRole: DoublesServerRole?) {
        let gameState = PadelGameState(
            firstServer: firstServer,
            settings: padelSettings,
            doublesStartingServerRole: doublesServerRole
        )
        navigationManager.navigationPath.append(gameState)
    }
}

// MARK: - Second screen: You or Partner
struct PadelDoublesServerRoleView: View, Hashable {
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var padelSettings: PadelSettings

    static func == (lhs: PadelDoublesServerRoleView, rhs: PadelDoublesServerRoleView) -> Bool {
        true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine("PadelDoublesServerRoleView")
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
        let gameState = PadelGameState(
            firstServer: .player1,
            settings: padelSettings,
            doublesStartingServerRole: doublesServerRole
        )
        navigationManager.navigationPath.append(gameState)
    }
}
