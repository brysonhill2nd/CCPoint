//
//  PickleballSettingsPageView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//

import SwiftUI

struct PickleballSettingsPageView: View {
    @EnvironmentObject var gameSettings: GameSettings

    var body: some View {
        Form {
            Section {
                Text("PICKLEBALL")
                    .font(WatchTypography.monoLabel(14))
                    .tracking(2)
                    .foregroundColor(WatchColors.green)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
            
            Section("Game Rules") {
                // Target Score
                Picker("Target Score", selection: $gameSettings.scoreLimitRawValue) {
                    Text("11").tag(11)
                    Text("15").tag(15)
                    Text("21").tag(21)
                    Text("Unlimited").tag(0)
                }
                
                // Win By 2
                Toggle("Win By 2", isOn: $gameSettings.winByTwo)
            }

            Section("Match Format") {
                Picker("Format", selection: $gameSettings.matchFormatType) {
                    ForEach(GameSettings.MatchFormatType.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                
                if gameSettings.matchFormatType == .firstTo {
                    HStack {
                        Text("Games:")
                            .font(.caption)
                        Spacer()
                        HStack(spacing: 15) {
                            Button("-") {
                                if gameSettings.firstToGamesCount > 1 {
                                    gameSettings.firstToGamesCount -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Text("\(gameSettings.firstToGamesCount)")
                                .font(.caption)
                                .frame(minWidth: 20)
                            
                            Button("+") {
                                if gameSettings.firstToGamesCount < 10 {
                                    gameSettings.firstToGamesCount += 1
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .onDisappear {
            // Sync settings to iPhone when leaving settings page
            WatchConnectivityManager.shared.syncSettingsToPhone(pickleballSettings: gameSettings)
        }
    }
}
