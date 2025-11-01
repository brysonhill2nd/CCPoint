//
//  PickleballScoreSelectionView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//


//
//  PickleballScoreSelectionView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//

import SwiftUI

struct PickleballScoreSelectionView: View {
    @EnvironmentObject var gameSettings: GameSettings
    @Environment(\.dismiss) var dismiss
    
    let scoreOptions = [11, 15, 21, 0] // 0 = Unlimited
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Target Score")
                .font(.headline)
                .padding(.bottom)
            
            ForEach(scoreOptions, id: \.self) { score in
                Button(action: {
                    gameSettings.scoreLimitRawValue = score
                    dismiss()
                }) {
                    VStack {
                        Text(score == 0 ? "Unlimited" : "\(score)")
                            .font(.headline)
                        if score != 0 {
                            Text("points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(gameSettings.scoreLimitRawValue == score ? .blue : .gray)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .navigationTitle("Score Limit")
        .navigationBarTitleDisplayMode(.inline)
    }
}