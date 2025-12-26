//
//  TennisScoreSideView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//  Updated with Swiss Design System
//
import SwiftUI

struct TennisScoreSideView: View {
    let score: String
    let setsWon: Int
    let gamesWon: Int
    let isServing: Bool
    let isSecondServer: Bool
    let totalServersInTeam: Int
    let playerColor: Color

    // Swiss Design System
    let scoreBackgroundColor = WatchColors.surface
    let scoreCornerRadius: CGFloat = 12
    let serviceDotSize: CGFloat = 8

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Score display - Swiss style
            Text(score)
                .font(WatchTypography.scoreLarge())
                .foregroundColor(WatchColors.textPrimary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: scoreCornerRadius)
                        .fill(scoreBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: scoreCornerRadius)
                        .stroke(isServing ? WatchColors.green : WatchColors.borderMuted, lineWidth: isServing ? 2 : 1)
                )
                .minimumScaleFactor(0.5)

            // Sets and Games - Swiss style
            HStack(spacing: 4) {
                // Set indicator
                Circle()
                    .fill(setsWon > 0 ? playerColor : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(playerColor.opacity(setsWon > 0 ? 0 : 0.5), lineWidth: 1)
                    )
                    .frame(width: 8, height: 8)

                Text("\(gamesWon)G")
                    .font(WatchTypography.monoLabel(10))
                    .foregroundColor(playerColor)
            }

            // Service dots - Swiss style
            HStack(spacing: 4) {
                if totalServersInTeam == 1 {
                    Circle()
                        .fill(isServing ? WatchColors.serviceActive : WatchColors.serviceInactive)
                        .frame(width: serviceDotSize, height: serviceDotSize)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: serviceDotSize, height: serviceDotSize)
                } else {
                    Circle()
                        .fill(isServing ? WatchColors.serviceActive : WatchColors.serviceInactive)
                        .frame(width: serviceDotSize, height: serviceDotSize)
                    Circle()
                        .fill(isServing && isSecondServer ? WatchColors.serviceActive : WatchColors.serviceInactive)
                        .frame(width: serviceDotSize, height: serviceDotSize)
                }
            }
            .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
