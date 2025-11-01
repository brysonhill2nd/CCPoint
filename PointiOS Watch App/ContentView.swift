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
                        .frame(height: 80)
                        .padding(.horizontal, 20)
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
                    
                    // MARK: - Added Test View for Debugging
                    Divider()
                    TestSyncView()

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

// Add this to your Watch app's ContentView or settings:
struct TestSyncView: View {
    var body: some View {
        VStack(spacing: 10) {
            Button("Test Context Save") {
                testContextSave()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Check Current Context") {
                checkCurrentContext()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    func testContextSave() {
        let testData: [String: Any] = [
            "testGame": [
                "timestamp": Date().timeIntervalSince1970,
                "message": "Test game from Watch",
                "score": "11-0"
            ]
        ]
        
        do {
            try WCSession.default.updateApplicationContext(testData)
            print("⌚ TEST: Saved test data to context")
            
            // Verify
            let context = WCSession.default.applicationContext
            print("⌚ TEST: Current context: \(context)")
        } catch {
            print("⌚ TEST ERROR: \(error)")
        }
    }
    
    func checkCurrentContext() {
        let context = WCSession.default.applicationContext
        print("⌚ CONTEXT CHECK: \(context)")
        print("⌚ CONTEXT KEYS: \(Array(context.keys))")
        print("⌚ CONTEXT EMPTY: \(context.isEmpty)")
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
