//
//  TennisFormatView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//
import SwiftUI

struct TennisFormatView: View, Hashable {
    @EnvironmentObject var navigationManager: NavigationManager
    
    static func == (lhs: TennisFormatView, rhs: TennisFormatView) -> Bool {
        true
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine("TennisFormat")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("SELECT FORMAT")
                .font(WatchTypography.monoLabel(11))
                .tracking(1)
                .foregroundColor(WatchColors.textSecondary)
                .padding(.bottom, 8)

            Button(action: {
                proceedToServerSelection(gameType: .singles)
            }) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                    Text("SINGLES")
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
                proceedToServerSelection(gameType: .doubles)
            }) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                    Text("DOUBLES")
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
    
    private func proceedToServerSelection(gameType: GameType) {
        let serverView = TennisFirstServerView(gameType: gameType)
        navigationManager.navigationPath.append(serverView)
    }
}
