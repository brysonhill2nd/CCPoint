//
//  PadelScoreSideView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//
import SwiftUI

struct PadelScoreSideView: View {
    let score: String
    let setsWon: Int
    let gamesWon: Int
    let isServing: Bool
    let isSecondServer: Bool
    let playerColor: Color
    
    let scoreBackgroundColor = Color.secondary.opacity(0.2)
    let scoreCornerRadius: CGFloat = 12
    let serviceDotSize: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            // Score display
            Text(score)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: scoreCornerRadius)
                        .fill(scoreBackgroundColor)
                )
                .minimumScaleFactor(0.5)
            
            // Sets and Games
            HStack(spacing: 4) {
                // Set dot
                Circle()
                    .fill(setsWon > 0 ? playerColor : Color.clear)
                    .stroke(playerColor, lineWidth: setsWon > 0 ? 0 : 1)
                    .frame(width: 8, height: 8)
                
                Text("\(gamesWon)G")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(playerColor)
            }
            
            // Service dots - PADEL IS ALWAYS DOUBLES
            HStack(spacing: 4) {
                // First server dot
                Circle()
                    .fill(isServing ? Color.green : Color.gray)
                    .frame(width: serviceDotSize, height: serviceDotSize)
                // Second server dot - only green when second server
                Circle()
                    .fill(isServing && isSecondServer ? Color.green : Color.gray)
                    .frame(width: serviceDotSize, height: serviceDotSize)
            }
            .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
