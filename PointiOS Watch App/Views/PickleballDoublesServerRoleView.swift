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
        VStack(spacing: 16) {
            Text("WHO ON YOUR TEAM?")
                .font(WatchTypography.monoLabel(11))
                .tracking(1)
                .foregroundColor(WatchColors.textSecondary)

            Text("Choose who starts serving")
                .font(WatchTypography.caption())
                .foregroundColor(WatchColors.textTertiary)
                .padding(.bottom, 8)

            Button {
                startGame(as: .you)
            } label: {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                    Text("YOU")
                        .font(WatchTypography.button())
                        .tracking(0.5)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WatchColors.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                startGame(as: .partner)
            } label: {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                    Text("PARTNER")
                        .font(WatchTypography.button())
                        .tracking(0.5)
                }
                .foregroundColor(WatchColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WatchColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(WatchColors.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
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
