//
//  TennisSettingsPageView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//

import SwiftUI

struct TennisSettingsPageView: View {
    @EnvironmentObject var tennisSettings: TennisSettings
    @EnvironmentObject var gameSettings: GameSettings
    
    var body: some View {
        Form {
            Section {
                Text("TENNIS")
                    .font(WatchTypography.monoLabel(14))
                    .tracking(2)
                    .foregroundColor(WatchColors.green)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
            
            Section("Game Rules") {
                // Scoring System
                Picker("Scoring System", selection: $tennisSettings.scoringSystem) {
                    ForEach(TennisSettings.ScoringSystem.allCases, id: \.self) { system in
                        Text(system.rawValue).tag(system)
                    }
                }
                
                // Golden Point
                Toggle("Golden Point", isOn: $tennisSettings.goldenPoint)
            }
            
            Section("Match Format") {
                // CHANGED: Use tennisSettings instead of gameSettings
                Picker("Format", selection: $tennisSettings.matchFormatType) {
                    ForEach(TennisSettings.MatchFormatType.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                
                if tennisSettings.matchFormatType == .firstTo {
                    HStack {
                        Text("Sets:")
                            .font(.caption)
                        Spacer()
                        HStack(spacing: 15) {
                            Button("-") {
                                // CHANGED: Use tennisSettings instead of gameSettings
                                if tennisSettings.firstToGamesCount > 1 {
                                    tennisSettings.firstToGamesCount -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            // CHANGED: Use tennisSettings instead of gameSettings
                            Text("\(tennisSettings.firstToGamesCount)")
                                .font(.caption)
                                .frame(minWidth: 20)
                            
                            Button("+") {
                                // CHANGED: Use tennisSettings instead of gameSettings
                                if tennisSettings.firstToGamesCount < 10 {
                                    tennisSettings.firstToGamesCount += 1
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
