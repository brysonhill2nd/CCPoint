//
//  GameTypeSelectionView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//

import SwiftUI

struct GameTypeSelectionView: View {
    @EnvironmentObject var navigationManager: NavigationManager
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Select Format")
                .font(.headline)
                .padding(.bottom)

            Button(action: {
                navigationManager.navigationPath.append(GameType.singles)
            }) {
                VStack {
                    Text("Singles")
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)

            Button(action: {
                navigationManager.navigationPath.append(GameType.doubles)
            }) {
                VStack {
                    Text("Doubles")
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
