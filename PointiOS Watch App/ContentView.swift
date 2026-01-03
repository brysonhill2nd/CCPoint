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

    private func sportEmoji(for sport: SportType) -> String {
        switch sport {
        case .pickleball: return "🥒"
        case .tennis: return "🎾"
        case .padel: return "🏓"
        }
    }

    var body: some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            ScrollView {
                VStack(spacing: 12) {
                    // Logo
                    Image("trans-dark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 96)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Sport selection buttons - Swiss style
                    ForEach(SportType.allCases) { sport in
                        Button(action: {
                            navigationManager.navigateToSport(sport)
                        }) {
                            HStack {
                                Text(sportEmoji(for: sport))
                                    .font(.system(size: 16))
                                Text(sport.rawValue.uppercased())
                                    .font(WatchTypography.button())
                                    .tracking(0.5)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(WatchColors.green)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    // Divider
                    Rectangle()
                        .fill(WatchColors.borderSubtle)
                        .frame(height: 1)
                        .padding(.vertical, 8)

                    // Secondary buttons
                    NavigationLink {
                        SwipeableSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14))
                            Text("SETTINGS")
                                .font(WatchTypography.button())
                                .tracking(0.5)
                        }
                        .foregroundColor(WatchColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(WatchColors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        HistoryView()
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14))
                            Text("HISTORY")
                                .font(WatchTypography.button())
                                .tracking(0.5)
                        }
                        .foregroundColor(WatchColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(WatchColors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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
            .navigationDestination(for: TennisDoublesServerRoleView.self) { view in
                view
            }
            .navigationDestination(for: TennisGameState.self) { gameState in
                EnhancedTennisGameView(gameState: gameState)
            }
            .navigationDestination(for: PadelFirstServerView.self) { view in
                view
            }
            .navigationDestination(for: PadelDoublesServerRoleView.self) { view in
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
