//
//  ScoreSideView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI

struct ScoreSideView: View {
    let score: Int
    let isServing: Bool
    let isSecondServerInTeam: Bool
    let totalServersInTeam: Int
    let dotSize: CGFloat
    let scoreFontSize: CGFloat
    
    // EXACT styling match to your original
    let scoreBackgroundColor = Color.secondary.opacity(0.2)
    let scoreCornerRadius: CGFloat = 10
    let activeColor = Color.filledServiceGreen
    let inactiveColor = Color.emptyServiceGray

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Score display - EXACT match to your formatting
            Text(String(format: "%02d", score))
                .font(.system(size: scoreFontSize, weight: .bold, design: .rounded))
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: scoreCornerRadius)
                        .fill(scoreBackgroundColor)
                )
                .minimumScaleFactor(0.5)
            
            // Service dots - EXACT match to your logic
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
                    // Doubles: Two dots with your exact logic
                    Circle()
                        .fill(isServing ? activeColor : inactiveColor)
                        .frame(width: dotSize, height: dotSize) // Dot 1
                    Circle()
                        .fill(isServing && isSecondServerInTeam ? activeColor : inactiveColor)
                        .frame(width: dotSize, height: dotSize) // Dot 2
                }
            }
            .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
