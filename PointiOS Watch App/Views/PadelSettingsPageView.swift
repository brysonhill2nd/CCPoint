//
//  PadelSettingsPageView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//

import SwiftUI

struct PadelSettingsPageView: View {
    @EnvironmentObject var padelSettings: PadelSettings
    @EnvironmentObject var gameSettings: GameSettings
    
    var body: some View {
        Form {
            Section {
                Text("Padel")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
            
            Section("Game Rules") {
                // Scoring System
                Picker("Scoring System", selection: $padelSettings.scoringSystem) {
                    ForEach(PadelSettings.ScoringSystem.allCases, id: \.self) { system in
                        Text(system.rawValue).tag(system)
                    }
                }
                
                // Golden Point
                Toggle("Golden Point", isOn: $padelSettings.goldenPoint)
            }
            
            Section("Match Format") {
                // CHANGED: Use padelSettings instead of gameSettings
                Picker("Format", selection: $padelSettings.matchFormatType) {
                    ForEach(PadelSettings.MatchFormatType.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                
                if padelSettings.matchFormatType == .firstTo {
                    HStack {
                        Text("Sets:")
                            .font(.caption)
                        Spacer()
                        HStack(spacing: 15) {
                            Button("-") {
                                // CHANGED: Use padelSettings instead of gameSettings
                                if padelSettings.firstToGamesCount > 1 {
                                    padelSettings.firstToGamesCount -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            // CHANGED: Use padelSettings instead of gameSettings
                            Text("\(padelSettings.firstToGamesCount)")
                                .font(.caption)
                                .frame(minWidth: 20)
                            
                            Button("+") {
                                // CHANGED: Use padelSettings instead of gameSettings
                                if padelSettings.firstToGamesCount < 10 {
                                    padelSettings.firstToGamesCount += 1
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}
