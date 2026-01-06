import Foundation

// MARK: - Core Insight Models

struct HeuristicGameInsights {
    let summary: String
    let strengths: [InsightDetail]
    let weaknesses: [InsightDetail]
    let recommendation: String
    let tone: InsightTone
}

struct InsightDetail {
    let title: String
    let description: String
    let icon: String
    let data: String
}

enum InsightTone {
    case dominant
    case clutch
    case competitive
    case rough
}

// MARK: - Source Data Structures

struct GameData {
    let playerScore: Int
    let opponentScore: Int
    let result: GameResult
    let points: [GamePoint]
    let sportType: String
}

enum GameResult {
    case win
    case loss
}

struct GamePoint {
    enum Participant {
        case player
        case opponent
    }
    
    let servedBy: Participant
    let wonBy: Participant
    let rallyLength: Int
    let currentScore: (player: Int, opponent: Int)
}

// MARK: - Insight Engine

final class InsightEngine {
    
    func analyzeGame(_ game: GameData) -> HeuristicGameInsights {
        let analysis = GameAnalysis(game: game)
        let tone = determineTone(analysis)
        let strengths = detectStrengths(analysis, tone: tone)
        let weaknesses = detectWeaknesses(analysis, tone: tone)
        let summary = generateSummary(analysis, tone: tone)
        let recommendation = generateRecommendation(analysis, tone: tone)
        
        return HeuristicGameInsights(
            summary: summary,
            strengths: strengths,
            weaknesses: weaknesses,
            recommendation: recommendation,
            tone: tone
        )
    }
    
    // MARK: Tone
    func determineTone(_ analysis: GameAnalysis) -> InsightTone {
        let scoreDiff = abs(analysis.game.playerScore - analysis.game.opponentScore)
        let won = analysis.game.result == .win
        let dominantMargin = dominantMargin(for: analysis.game.sportType)
        let closeMargin = closeMargin(for: analysis.game.sportType)
        let backAndForth = analysis.leadChanges >= 3
        let closeGame = scoreDiff <= closeMargin

        if won {
            if scoreDiff >= dominantMargin && !analysis.hadComeback && !backAndForth {
                return .dominant
            }
            return .clutch
        } else {
            if closeGame || backAndForth || analysis.blewLead {
                return .competitive
            }
            return .rough
        }
    }
    
    // MARK: Strengths
    func detectStrengths(_ analysis: GameAnalysis, tone: InsightTone) -> [InsightDetail] {
        var strengths: [InsightDetail] = []
        
        if analysis.servingEfficiency >= 0.65, analysis.totalServePoints > 0 {
            strengths.append(
                InsightDetail(
                    title: "Serving Weapon",
                    description: "\(analysis.pointsWonOnServe) of \(analysis.totalServePoints) points came from your serve - it's dominating",
                    icon: "⚡",
                    data: "\(Int(analysis.servingEfficiency * 100))%"
                )
            )
        }
        
        if analysis.longRallyWinRate >= 0.70, analysis.longRallies.count >= 3 {
            strengths.append(
                InsightDetail(
                    title: "Rally Master",
                    description: "Won \(Int(analysis.longRallyWinRate * 100))% of long rallies - your patience wears them down",
                    icon: "⏱️",
                    data: "\(analysis.longRallies.count) rallies"
                )
            )
        }
        
        if let longestRun = analysis.longestPointStreak, longestRun >= 4 {
            strengths.append(
                InsightDetail(
                    title: "Momentum Builder",
                    description: "\(longestRun)-point streak sealed the game",
                    icon: "🔥",
                    data: "\(longestRun) points"
                )
            )
        }
        
        if analysis.hadComeback, tone == .clutch {
            strengths.append(
                InsightDetail(
                    title: "Comeback King",
                    description: "Down \(analysis.maxDeficit) points but fought back to win",
                    icon: "👑",
                    data: "From -\(analysis.maxDeficit)"
                )
            )
        }

        if analysis.leadChanges >= 3, tone == .clutch {
            strengths.append(
                InsightDetail(
                    title: "Clutch Finish",
                    description: "Navigated \(analysis.leadChanges) lead changes and closed strong",
                    icon: "✨",
                    data: "\(analysis.leadChanges) swings"
                )
            )
        }
        
        return strengths
    }
    
    // MARK: Weaknesses
    func detectWeaknesses(_ analysis: GameAnalysis, tone: InsightTone) -> [InsightDetail] {
        var weaknesses: [InsightDetail] = []
        
        if analysis.sideOutRate < 0.35, analysis.totalReturnPoints > 0 {
            weaknesses.append(
                InsightDetail(
                    title: "Return Vulnerability",
                    description: "Only won \(analysis.pointsWonOnReturn) of \(analysis.totalReturnPoints) points on their serve",
                    icon: "⚠️",
                    data: "\(Int(analysis.sideOutRate * 100))%"
                )
            )
        }
        
        if analysis.quickRallyWinRate < 0.35, analysis.quickRallies.count >= 5 {
            weaknesses.append(
                InsightDetail(
                    title: "Fast Exchange Issues",
                    description: "Won only \(analysis.quickRalliesWon) of \(analysis.quickRallies.count) quick rallies - stay ready at net",
                    icon: "⚡",
                    data: "\(Int(analysis.quickRallyWinRate * 100))%"
                )
            )
        }
        
        if analysis.blewLead, tone == .rough {
            weaknesses.append(
                InsightDetail(
                    title: "Lead Management",
                    description: "Led by \(analysis.maxLead) but couldn't maintain momentum",
                    icon: "📉",
                    data: "Max lead: \(analysis.maxLead)"
                )
            )
        }
        
        if analysis.pointsLostWhileServing >= 5 {
            weaknesses.append(
                InsightDetail(
                    title: "Serve Defense",
                    description: "Lost \(analysis.pointsLostWhileServing) points while serving - improve positioning",
                    icon: "🎯",
                    data: "\(analysis.pointsLostWhileServing) points"
                )
            )
        }

        if analysis.leadChanges >= 4, tone == .competitive {
            weaknesses.append(
                InsightDetail(
                    title: "Momentum Swings",
                    description: "Too many lead changes made it hard to stabilize",
                    icon: "🌀",
                    data: "\(analysis.leadChanges) swings"
                )
            )
        }
        
        return weaknesses
    }
    
    // MARK: Summary & Recommendation
    func generateSummary(_ analysis: GameAnalysis, tone: InsightTone) -> String {
        let serveRate = Int((analysis.servingEfficiency * 100).rounded())
        let returnRate = Int((analysis.sideOutRate * 100).rounded())
        let leadChanges = analysis.leadChanges

        switch tone {
        case .dominant:
            if analysis.game.opponentScore == 0 {
                return "Perfect game! Complete dominance from start to finish."
            }
            if serveRate >= 65 {
                return "Dominant win. You controlled the match and held serve at \(serveRate)%."
            }
            return "Dominant performance. You controlled the game and never let them back in."
        case .clutch:
            if analysis.hadComeback {
                return "Gutsy win! You erased a \(analysis.maxDeficit)-point deficit and finished strong."
            }
            if leadChanges >= 3 {
                return "Tight match with \(leadChanges) lead changes. You executed when it mattered."
            }
            return "Tight match that could've gone either way. You executed when it mattered."
        case .competitive:
            if analysis.blewLead {
                return "You led by \(analysis.maxLead) but couldn’t close. The finish swung late."
            }
            if leadChanges >= 3 {
                return "Back-and-forth battle with \(leadChanges) lead changes. You were right there."
            }
            return "Close battle that came down to a few key points. You were right there."
        case .rough:
            if analysis.game.playerScore == 0 {
                return "Tough match. Got shut out. Focus on basics and come back stronger."
            }
            if returnRate > 0 {
                return "Struggled to find rhythm today. Returns converted at \(returnRate)%."
            }
            return "Struggled to find rhythm today. Analyze what went wrong and adjust."
        }
    }
    
    func generateRecommendation(_ analysis: GameAnalysis, tone: InsightTone) -> String {
        if analysis.sideOutRate < 0.30 {
            return "Your return game is costing you matches. Practice aggressive returns - aim for their feet or go down the line to take control early."
        }
        
        if analysis.servingEfficiency >= 0.70 {
            return "Your serve is a weapon. Next game, be even more aggressive with it and force them into defensive positions from the start."
        }
        
        if analysis.blewLead {
            return "Work on maintaining leads. When up big, stay aggressive and don't let opponents build confidence with cheap points."
        }
        
        if analysis.longRallyWinRate >= 0.70 {
            return "You dominate long rallies. Next game, be patient and avoid going for low-percentage winners early in points."
        }
        
        return "Focus on consistent play. Your strengths are working - lean into them while cleaning up the easy errors."
    }
}

// MARK: - Game Analysis Helper

struct GameAnalysis {
    let game: GameData
    
    // Serving stats
    var totalServePoints: Int {
        game.points.filter { $0.servedBy == .player }.count
    }
    
    var pointsWonOnServe: Int {
        game.points.filter { $0.servedBy == .player && $0.wonBy == .player }.count
    }
    
    var pointsLostWhileServing: Int {
        max(0, totalServePoints - pointsWonOnServe)
    }
    
    var servingEfficiency: Double {
        guard totalServePoints > 0 else { return 0 }
        return Double(pointsWonOnServe) / Double(totalServePoints)
    }
    
    // Return stats
    var totalReturnPoints: Int {
        game.points.filter { $0.servedBy == .opponent }.count
    }
    
    var pointsWonOnReturn: Int {
        game.points.filter { $0.servedBy == .opponent && $0.wonBy == .player }.count
    }
    
    var sideOutRate: Double {
        guard totalReturnPoints > 0 else { return 0 }
        return Double(pointsWonOnReturn) / Double(totalReturnPoints)
    }
    
    // Rally patterns
    var longRallies: [GamePoint] {
        game.points.filter { $0.rallyLength >= 8 }
    }
    
    var longRallyWinRate: Double {
        guard !longRallies.isEmpty else { return 0 }
        let won = longRallies.filter { $0.wonBy == .player }.count
        return Double(won) / Double(longRallies.count)
    }
    
    var quickRallies: [GamePoint] {
        game.points.filter { $0.rallyLength <= 3 }
    }
    
    var quickRalliesWon: Int {
        quickRallies.filter { $0.wonBy == .player }.count
    }
    
    var quickRallyWinRate: Double {
        guard !quickRallies.isEmpty else { return 0 }
        return Double(quickRalliesWon) / Double(quickRallies.count)
    }
    
    // Momentum tracking
    var longestPointStreak: Int? {
        guard !game.points.isEmpty else { return nil }
        var currentStreak = 0
        var maxStreak = 0
        
        for point in game.points {
            if point.wonBy == .player {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        
        return maxStreak >= 1 ? maxStreak : nil
    }
    
    var hadComeback: Bool {
        maxDeficit >= 4 && game.result == .win
    }
    
    var blewLead: Bool {
        maxLead >= 5 && game.result == .loss
    }
    
    var maxLead: Int {
        var lead = 0
        for point in game.points {
            let currentLead = point.currentScore.player - point.currentScore.opponent
            lead = max(lead, currentLead)
        }
        return lead
    }
    
    var maxDeficit: Int {
        var deficit = 0
        for point in game.points {
            let currentDeficit = point.currentScore.opponent - point.currentScore.player
            deficit = max(deficit, currentDeficit)
        }
        return deficit
    }

    var leadChanges: Int {
        var changes = 0
        var lastLeader: GamePoint.Participant? = nil
        for point in game.points {
            let leader: GamePoint.Participant? = {
                if point.currentScore.player > point.currentScore.opponent { return .player }
                if point.currentScore.opponent > point.currentScore.player { return .opponent }
                return nil
            }()
            if let current = leader, let previous = lastLeader, current != previous {
                changes += 1
            }
            if leader != nil {
                lastLeader = leader
            }
        }
        return changes
    }
}

private extension InsightEngine {
    func dominantMargin(for sport: String) -> Int {
        let lower = sport.lowercased()
        if lower.contains("tennis") { return 3 }
        return 5
    }

    func closeMargin(for sport: String) -> Int {
        let lower = sport.lowercased()
        if lower.contains("tennis") { return 1 }
        return 2
    }
}
