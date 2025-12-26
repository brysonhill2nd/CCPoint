//
//  SettingsCard.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//  Updated with Swiss Design System
//

import SwiftUI

struct SettingsCard: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(WatchTypography.monoLabel(10))
                        .tracking(0.5)
                        .foregroundColor(WatchColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(value)
                        .font(WatchTypography.scoreMedium())
                        .foregroundColor(WatchColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WatchColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(WatchColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(WatchColors.borderMuted, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
