import SwiftUI

struct PickleballDoublesServerRoleView: View, Hashable {
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var gameSettings: GameSettings

    let initialPlayer1Games: Int
    let initialPlayer2Games: Int
    private let viewID = UUID()

    static func == (lhs: PickleballDoublesServerRoleView, rhs: PickleballDoublesServerRoleView) -> Bool {
        lhs.viewID == rhs.viewID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(viewID)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Who is serving first?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            Text("Choose which teammate starts the serve.")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button {
                startGame(as: .you)
            } label: {
                Text("You")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button {
                startGame(as: .partner)
            } label: {
                Text("Partner")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startGame(as role: DoublesServerRole) {
        let gameState = GameState(
            gameType: .doubles,
            firstServer: .player1,
            settings: gameSettings,
            initialPlayer1Games: initialPlayer1Games,
            initialPlayer2Games: initialPlayer2Games,
            doublesStartingServerRole: role
        )
        navigationManager.navigationPath.append(gameState)
    }
}
