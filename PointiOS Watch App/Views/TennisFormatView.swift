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
        VStack(spacing: 25) {
            Text("Select Format")
                .font(.headline)
                .padding(.bottom)

            Button(action: {
                proceedToServerSelection(gameType: .singles)
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
                proceedToServerSelection(gameType: .doubles)
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
    
    private func proceedToServerSelection(gameType: GameType) {
        let serverView = TennisFirstServerView(gameType: gameType)
        navigationManager.navigationPath.append(serverView)
    }
}
