//
//  ScoreSideView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//  Updated with Swiss Design System
//
import SwiftUI

struct ScoreSideView: View {
    let score: Int
    let isServing: Bool
    let isSecondServerInTeam: Bool
    let totalServersInTeam: Int
    let dotSize: CGFloat
    let scoreFontSize: CGFloat

    // Swiss Design System colors
    let scoreBackgroundColor = WatchColors.surface
    let scoreCornerRadius: CGFloat = 12
    let activeColor = WatchColors.serviceActive
    let inactiveColor = WatchColors.serviceInactive

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Score display - Swiss style
            Text(String(format: "%02d", score))
                .font(.system(size: scoreFontSize, weight: .bold, design: .rounded))
                .foregroundColor(WatchColors.textPrimary)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: scoreCornerRadius)
                        .fill(scoreBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: scoreCornerRadius)
                        .stroke(isServing ? WatchColors.green : WatchColors.borderMuted, lineWidth: isServing ? 2 : 1)
                )
                .minimumScaleFactor(0.5)

            // Service dots - Swiss style
            HStack(spacing: 5) {
                if totalServersInTeam == 1 {
                    // Singles: One dot + clear spacer
                    Circle()
                        .fill(isServing ? activeColor : inactiveColor)
                        .frame(width: dotSize, height: dotSize)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: dotSize, height: dotSize)
                } else {
                    // Doubles: Two dots
                    Circle()
                        .fill(isServing ? activeColor : inactiveColor)
                        .frame(width: dotSize, height: dotSize)
                    Circle()
                        .fill(isServing && isSecondServerInTeam ? activeColor : inactiveColor)
                        .frame(width: dotSize, height: dotSize)
                }
            }
            .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
