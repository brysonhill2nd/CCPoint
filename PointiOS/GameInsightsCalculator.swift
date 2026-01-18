//
//  GameInsightsCalculator.swift
//  PointiOS
//
//  Calculates actionable insights from game event data
//

import Foundation

// MARK: - Key Moment (Highlight)
struct KeyMoment {
    let title: String
    let description: String
    let score: String
    let icon: String
    let isPositive: Bool
}

// MARK: - Simple Game Insights (for SwissGameDetailView)
struct iOSGameInsights {
    let events: [GameEventData]
    let isWin: Bool
    let sport: String

    // MARK: - Serve Performance
    var yourServeWinPercentage: Int {
        let yourServeEvents = events.filter { $0.servingPlayer == "player1" }
        guard !yourServeEvents.isEmpty else { return 0 }
        let won = yourServeEvents.filter { $0.scoringPlayer == "player1" }.count
        return Int(Double(won) / Double(yourServeEvents.count) * 100)
    }

    var opponentServeWinPercentage: Int {
        let oppServeEvents = events.filter { $0.servingPlayer == "player2" }
        guard !oppServeEvents.isEmpty else { return 0 }
        let won = oppServeEvents.filter { $0.scoringPlayer == "player2" }.count
        return Int(Double(won) / Double(oppServeEvents.count) * 100)
    }

    var pointsWonOnServe: Int {
        events.filter { $0.servingPlayer == "player1" && $0.scoringPlayer == "player1" }.count
    }

    var totalServePoints: Int {
        events.filter { $0.servingPlayer == "player1" }.count
    }

    // MARK: - Momentum
    var longestYourRun: Int {
        var maxRun = 0
        var currentRun = 0
        for event in events {
            if event.scoringPlayer == "player1" {
                currentRun += 1
                maxRun = max(maxRun, currentRun)
            } else {
                currentRun = 0
            }
        }
        return maxRun
    }

    var longestOpponentRun: Int {
        var maxRun = 0
        var currentRun = 0
        for event in events {
            if event.scoringPlayer == "player2" {
                currentRun += 1
                maxRun = max(maxRun, currentRun)
            } else {
                currentRun = 0
            }
        }
        return maxRun
    }

    var leadChanges: Int {
        var changes = 0
        var lastLeader: String? = nil
        for event in events {
            let leader: String? = {
                if event.player1Score > event.player2Score { return "player1" }
                else if event.player2Score > event.player1Score { return "player2" }
                else { return nil }
            }()
            if let current = leader, current != lastLeader, lastLeader != nil {
                changes += 1
            }
            lastLeader = leader
        }
        return changes
    }

    var momentumSummary: String {
        if longestYourRun >= 5 {
            return "You dominated with a \(longestYourRun)-point scoring run. \(isWin ? "This momentum carried you to victory." : "Despite this run, you couldn't close it out.")"
        } else if longestOpponentRun >= 5 {
            return "Your opponent had a strong \(longestOpponentRun)-point run. \(isWin ? "You recovered well to secure the win." : "This shift in momentum proved decisive.")"
        } else if leadChanges >= 4 {
            return "A closely contested match with \(leadChanges) lead changes. \(isWin ? "You showed resilience to pull ahead." : "The back-and-forth ultimately went their way.")"
        } else {
            return isWin ? "You controlled the pace throughout, maintaining pressure on your opponent." : "Your opponent maintained control for most of the match."
        }
    }

    // MARK: - Key Moments (Highlights)
    var keyMoments: [KeyMoment] {
        var moments: [KeyMoment] = []

        // Find longest run
        var currentRun = 0
        var bestRunEnd = 0
        var bestRunLength = 0

        for (index, event) in events.enumerated() {
            if event.scoringPlayer == "player1" {
                currentRun += 1
                if currentRun > bestRunLength {
                    bestRunLength = currentRun
                    bestRunEnd = index
                }
            } else {
                currentRun = 0
            }
        }

        if bestRunLength >= 3, bestRunEnd < events.count {
            let endEvent = events[bestRunEnd]
            moments.append(KeyMoment(
                title: "\(bestRunLength)-Point Run",
                description: "Scored \(bestRunLength) consecutive points",
                score: "\(endEvent.player1Score)-\(endEvent.player2Score)",
                icon: "flame.fill",
                isPositive: true
            ))
        }

        // Find comeback (if you came back from 3+ point deficit)
        var maxDeficit = 0
        var comebackEvent: GameEventData? = nil
        for event in events {
            let deficit = event.player2Score - event.player1Score
            if deficit > maxDeficit {
                maxDeficit = deficit
            }
            // If we were behind and now ahead
            if maxDeficit >= 3 && event.player1Score > event.player2Score && comebackEvent == nil {
                comebackEvent = event
            }
        }

        if let comeback = comebackEvent, maxDeficit >= 3 {
            moments.append(KeyMoment(
                title: "Comeback",
                description: "Overcame a \(maxDeficit)-point deficit",
                score: "\(comeback.player1Score)-\(comeback.player2Score)",
                icon: "arrow.up.circle.fill",
                isPositive: true
            ))
        }

        // Find clutch point (close game, you scored)
        for event in events.reversed() {
            if event.player1Score >= 9 && event.player2Score >= 9 && event.scoringPlayer == "player1" {
                moments.append(KeyMoment(
                    title: "Clutch Point",
                    description: "Scored under pressure at \(event.player1Score - 1)-\(event.player2Score)",
                    score: "\(event.player1Score)-\(event.player2Score)",
                    icon: "star.fill",
                    isPositive: true
                ))
                break
            }
        }

        // Find serve ace/winner (first serve point won)
        if let firstServeWin = events.first(where: { $0.servingPlayer == "player1" && $0.scoringPlayer == "player1" && $0.shotType == "Serve" }) {
            moments.append(KeyMoment(
                title: "Service Winner",
                description: "Won point directly on serve",
                score: "\(firstServeWin.player1Score)-\(firstServeWin.player2Score)",
                icon: "bolt.fill",
                isPositive: true
            ))
        }

        // If losing, find opponent's key moment
        if !isWin {
            var oppRunLength = 0
            var oppBestRun = 0
            var oppRunEvent: GameEventData? = nil

            for event in events {
                if event.scoringPlayer == "player2" {
                    oppRunLength += 1
                    if oppRunLength > oppBestRun {
                        oppBestRun = oppRunLength
                        oppRunEvent = event
                    }
                } else {
                    oppRunLength = 0
                }
            }

            if oppBestRun >= 3, let event = oppRunEvent {
                moments.append(KeyMoment(
                    title: "Opponent's Run",
                    description: "They scored \(oppBestRun) in a row",
                    score: "\(event.player1Score)-\(event.player2Score)",
                    icon: "exclamationmark.triangle.fill",
                    isPositive: false
                ))
            }
        }

        return moments
    }
}

// MARK: - Insights Models

struct ServeInsights {
    let youServedPoints: Int
    let youServedPointsWon: Int
    let partnerServedPoints: Int
    let partnerServedPointsWon: Int
    let opponentServedPoints: Int
    let opponentServedPointsDefended: Int  // For pickleball - side outs forced
    let opponentServedPointsWon: Int       // For tennis/padel - break points won

    var yourServeWinRate: Double {
        guard youServedPoints > 0 else { return 0 }
        return Double(youServedPointsWon) / Double(youServedPoints)
    }

    var partnerServeWinRate: Double {
        guard partnerServedPoints > 0 else { return 0 }
        return Double(partnerServedPointsWon) / Double(partnerServedPoints)
    }

    var returnDefenseRate: Double {
        guard opponentServedPoints > 0 else { return 0 }
        return Double(opponentServedPointsDefended) / Double(opponentServedPoints)
    }

    var returnWinRate: Double {
        guard opponentServedPoints > 0 else { return 0 }
        return Double(opponentServedPointsWon) / Double(opponentServedPoints)
    }
}

struct MomentumInsights {
    let yourMaxStreak: Int
    let opponentMaxStreak: Int
    let leadChanges: Int
    let yourBiggestLead: Int
    let opponentBiggestLead: Int

    var momentumAdvantage: String {
        if yourMaxStreak > opponentMaxStreak + 2 {
            return "You dominated momentum with a \(yourMaxStreak)-point run"
        } else if opponentMaxStreak > yourMaxStreak + 2 {
            return "Opponent had momentum with a \(opponentMaxStreak)-point run"
        } else if leadChanges > 5 {
            return "Back-and-forth battle with \(leadChanges) lead changes"
        } else {
            return "Evenly contested match"
        }
    }
}

struct ClutchInsights {
    let gamePointsPlayed: Int      // 10-10 in PB, deuce in tennis, etc.
    let gamePointsWon: Int
    let breakPointsPlayed: Int     // Opponent serving, you have chance to break
    let breakPointsConverted: Int

    var clutchRate: Double {
        guard gamePointsPlayed > 0 else { return 0 }
        return Double(gamePointsWon) / Double(gamePointsPlayed)
    }

    var breakPointConversionRate: Double {
        guard breakPointsPlayed > 0 else { return 0 }
        return Double(breakPointsConverted) / Double(breakPointsPlayed)
    }
}

struct GameInsightsResult {
    let serveInsights: ServeInsights
    let momentumInsights: MomentumInsights
    let clutchInsights: ClutchInsights
    let isDoubles: Bool
    let sportType: String
}

// MARK: - Calculator

class GameInsightsCalculator {

    static func calculate(from game: WatchGameRecord) -> GameInsightsResult? {
        guard let events = game.events, events.count > 1 else { return nil }

        let isDoubles = game.gameType == "Doubles"
        let isPickleball = game.sportType == "Pickleball"

        let serveInsights = calculateServeInsights(events: events, isDoubles: isDoubles, isPickleball: isPickleball)
        let momentumInsights = calculateMomentumInsights(events: events)
        let clutchInsights = calculateClutchInsights(events: events, sportType: game.sportType)

        return GameInsightsResult(
            serveInsights: serveInsights,
            momentumInsights: momentumInsights,
            clutchInsights: clutchInsights,
            isDoubles: isDoubles,
            sportType: game.sportType
        )
    }

    // MARK: - Serve Insights

    private static func calculateServeInsights(events: [GameEventData], isDoubles: Bool, isPickleball: Bool) -> ServeInsights {
        var youServedPoints = 0
        var youServedPointsWon = 0
        var partnerServedPoints = 0
        var partnerServedPointsWon = 0
        var opponentServedPoints = 0
        var opponentServedPointsDefended = 0  // Side outs in pickleball
        var opponentServedPointsWon = 0       // Breaks in tennis/padel

        for event in events {
            guard let servingPlayer = event.servingPlayer else { continue }

            let player1Scored = event.scoringPlayer == "player1"

            if servingPlayer == "player1" {
                // Your team served
                if isDoubles {
                    if event.doublesServerRole == "you" {
                        youServedPoints += 1
                        if player1Scored { youServedPointsWon += 1 }
                    } else if event.doublesServerRole == "partner" {
                        partnerServedPoints += 1
                        if player1Scored { partnerServedPointsWon += 1 }
                    }
                } else {
                    // Singles - you served
                    youServedPoints += 1
                    if player1Scored { youServedPointsWon += 1 }
                }
            } else {
                // Opponent served
                opponentServedPoints += 1
                if player1Scored {
                    // You won while opponent was serving
                    if isPickleball {
                        opponentServedPointsDefended += 1  // Side out
                    } else {
                        opponentServedPointsWon += 1  // Break point won
                    }
                }
            }
        }

        return ServeInsights(
            youServedPoints: youServedPoints,
            youServedPointsWon: youServedPointsWon,
            partnerServedPoints: partnerServedPoints,
            partnerServedPointsWon: partnerServedPointsWon,
            opponentServedPoints: opponentServedPoints,
            opponentServedPointsDefended: opponentServedPointsDefended,
            opponentServedPointsWon: opponentServedPointsWon
        )
    }

    // MARK: - Momentum Insights

    private static func calculateMomentumInsights(events: [GameEventData]) -> MomentumInsights {
        var yourMaxStreak = 0
        var opponentMaxStreak = 0
        var currentStreak = 0
        var currentStreakPlayer: String? = nil
        var leadChanges = 0
        var lastLeader: String? = nil
        var yourBiggestLead = 0
        var opponentBiggestLead = 0

        for event in events {
            let scorer = event.scoringPlayer

            // Track streaks
            if scorer == currentStreakPlayer {
                currentStreak += 1
            } else {
                currentStreak = 1
                currentStreakPlayer = scorer
            }

            if scorer == "player1" {
                yourMaxStreak = max(yourMaxStreak, currentStreak)
            } else {
                opponentMaxStreak = max(opponentMaxStreak, currentStreak)
            }

            // Track lead changes
            let currentLeader: String? = {
                if event.player1Score > event.player2Score { return "player1" }
                else if event.player2Score > event.player1Score { return "player2" }
                else { return nil }
            }()

            if let current = currentLeader, current != lastLeader, lastLeader != nil {
                leadChanges += 1
            }
            lastLeader = currentLeader

            // Track biggest leads
            let lead = event.player1Score - event.player2Score
            if lead > 0 {
                yourBiggestLead = max(yourBiggestLead, lead)
            } else if lead < 0 {
                opponentBiggestLead = max(opponentBiggestLead, -lead)
            }
        }

        return MomentumInsights(
            yourMaxStreak: yourMaxStreak,
            opponentMaxStreak: opponentMaxStreak,
            leadChanges: leadChanges,
            yourBiggestLead: yourBiggestLead,
            opponentBiggestLead: opponentBiggestLead
        )
    }

    // MARK: - Clutch Insights

    private static func calculateClutchInsights(events: [GameEventData], sportType: String) -> ClutchInsights {
        var gamePointsPlayed = 0
        var gamePointsWon = 0
        var breakPointsPlayed = 0
        var breakPointsConverted = 0

        let isPickleball = sportType == "Pickleball"

        for event in events {
            let p1 = event.player1Score
            let p2 = event.player2Score

            if isPickleball {
                // Pickleball: game point at 10-10 or higher when tied
                if p1 >= 10 && p2 >= 10 && abs(p1 - p2) <= 1 {
                    gamePointsPlayed += 1
                    if event.scoringPlayer == "player1" {
                        gamePointsWon += 1
                    }
                }
            } else {
                // Tennis/Padel: deuce situation (3-3 or higher, equal)
                if p1 >= 3 && p2 >= 3 && p1 == p2 {
                    gamePointsPlayed += 1
                    if event.scoringPlayer == "player1" {
                        gamePointsWon += 1
                    }
                }
            }

            // Break point: opponent serving and you have game/set point
            if event.servingPlayer == "player2" {
                if isPickleball {
                    // In pickleball, any side out when opponent serves is a "break"
                    // But we track specifically when you then go on to score
                    // This is tracked in serve insights
                } else {
                    // Tennis/Padel: you're at 40 (3 points) and opponent is serving
                    if p1 >= 3 && p1 > p2 {
                        breakPointsPlayed += 1
                        if event.scoringPlayer == "player1" {
                            breakPointsConverted += 1
                        }
                    }
                }
            }
        }

        return ClutchInsights(
            gamePointsPlayed: gamePointsPlayed,
            gamePointsWon: gamePointsWon,
            breakPointsPlayed: breakPointsPlayed,
            breakPointsConverted: breakPointsConverted
        )
    }
}
