//
//  GameTypeSelectionView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//  Updated with Swiss Design System
//

import SwiftUI

struct GameTypeSelectionView: View {
    @EnvironmentObject var navigationManager: NavigationManager

    var body: some View {
        VStack(spacing: 16) {
            Text("SELECT FORMAT")
                .font(WatchTypography.monoLabel(11))
                .tracking(1)
                .foregroundColor(WatchColors.textSecondary)
                .padding(.bottom, 8)

            // Singles button - Swiss style
            Button(action: {
                navigationManager.navigationPath.append(GameType.singles)
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

            // Doubles button - Swiss style
            Button(action: {
                navigationManager.navigationPath.append(GameType.doubles)
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
}
