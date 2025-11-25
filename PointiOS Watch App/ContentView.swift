//
//  ContentView.swift
//  ClaudePoint Watch App
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @EnvironmentObject var gameSettings: GameSettings
    @EnvironmentObject var tennisSettings: TennisSettings
    @EnvironmentObject var padelSettings: PadelSettings
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var historyManager: HistoryManager

    var body: some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            ScrollView {
                VStack(spacing: 15) { // Adjusted spacing
                    Image("Image")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 5)
                                        
                    // Sport selection buttons
                    ForEach(SportType.allCases) { sport in
                        Button(action: {
                            navigationManager.navigateToSport(sport)
                        }) {
                            Text(sport.rawValue)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    Divider()
                    
                    NavigationLink(value: NavigationTarget.settings) {
                        Text("Settings")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    NavigationLink(value: NavigationTarget.history) {
                        Text("History")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    #if DEBUG
                    // MARK: - Debug Tools (only in debug builds)
                    Divider()
                    NavigationLink(destination: MotionTrackerView()) {
                        Text("Motion Tracking Debug")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    #endif

                }
                .padding()
            }
            .navigationDestination(for: NavigationTarget.self) { target in
                switch target {
                case .gameTypeSelection:
                    GameTypeSelectionView()
                case .settings:
                    SwipeableSettingsView()
                case .history:
                    HistoryView()
                case .sportSelection(let sport):
                    switch sport {
                    case .pickleball:
                        GameTypeSelectionView()
                    case .tennis:
                        TennisFormatView()
                    case .padel:
                        PadelFirstServerView()
                    }
                case .tennisFormat:
                    TennisFormatView()
                case .padelFirstServer:
                    PadelFirstServerView()
                }
            }
            .navigationDestination(for: GameType.self) { gameType in
                FirstServerView(gameType: gameType)
            }
            .navigationDestination(for: GameState.self) { gameState in
                PickleballScoreView(gameState: gameState)
            }
            .navigationDestination(for: PickleballDoublesServerRoleView.self) { view in
                view
            }
            .navigationDestination(for: TennisFirstServerView.self) { view in
                view
            }
            .navigationDestination(for: TennisGameState.self) { gameState in
                EnhancedTennisGameView(gameState: gameState)
            }
            .navigationDestination(for: PadelFirstServerView.self) { view in
                view
            }
            .navigationDestination(for: PadelGameState.self) { gameState in
                EnhancedPadelGameView(gameState: gameState)
            }
            .navigationDestination(for: TennisFormatView.self) { view in
                view
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(GameSettings())
            .environmentObject(TennisSettings())
            .environmentObject(PadelSettings())
            .environmentObject(NavigationManager())
            .environmentObject(HistoryManager())
    }
}
