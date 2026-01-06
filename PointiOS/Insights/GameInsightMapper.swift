import Foundation

struct GameInsightMapper {
    static func map(record: WatchGameRecord) -> GameData? {
        guard let events = record.events, !events.isEmpty else {
            return nil
        }
        
        let points: [GamePoint] = events.map { event in
            let winnerParticipant: GamePoint.Participant = {
                if event.scoringPlayer.lowercased() == "player1" || event.scoringPlayer == "You" {
                    return .player
                } else {
                    return .opponent
                }
            }()
            
            let servedBy: GamePoint.Participant = {
                if event.isServePoint {
                    return winnerParticipant
                } else {
                    return winnerParticipant.opposite
                }
            }()
            
            let rallyLength = event.isServePoint ? 3 : 6
            
            return GamePoint(
                servedBy: servedBy,
                wonBy: winnerParticipant,
                rallyLength: rallyLength,
                currentScore: (player: event.player1Score, opponent: event.player2Score)
            )
        }
        
        let result: GameResult = (record.winner == "You") ? .win : .loss
        
        return GameData(
            playerScore: record.player1Score,
            opponentScore: record.player2Score,
            result: result,
            points: points,
            sportType: record.sportType
        )
    }
}

extension GamePoint.Participant {
    var opposite: GamePoint.Participant {
        switch self {
        case .player:
            return .opponent
        case .opponent:
            return .player
        }
    }
}
