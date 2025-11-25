//
//  InsightsEngine.swift
//  PointiOS
//
//  Shot analytics and insights generation
//

import Foundation

// MARK: - Shot Analytics Results
struct ShotAnalytics {
    let distribution: [ShotType: Int]
    let winningShots: [ShotType: WinRate]
    let averageRallyReactionTime: TimeInterval?
    let powerTrend: [ShotType: PowerStats]
    let topInsights: [String]
}

struct WinRate {
    let total: Int
    let wins: Int
    let percentage: Double
}

struct PowerStats {
    let average: Double
    let peak: Double
    let consistency: Double  // Lower is better (standard deviation)
}

// MARK: - Insights Engine
class InsightsEngine {
    static let shared = InsightsEngine()

    private init() {}

    // MARK: - Shot Distribution
    func shotDistribution(for game: WatchGameRecord) -> [ShotType: Int] {
        guard let shots = game.shots else { return [:] }

        var distribution: [ShotType: Int] = [:]
        for shot in shots {
            distribution[shot.type, default: 0] += 1
        }

        return distribution
    }

    func shotDistribution(for games: [WatchGameRecord]) -> [ShotType: Int] {
        var distribution: [ShotType: Int] = [:]

        for game in games {
            guard let shots = game.shots else { continue }
            for shot in shots {
                distribution[shot.type, default: 0] += 1
            }
        }

        return distribution
    }

    // MARK: - Win Rate by Shot Type
    func winRateByShotType(for game: WatchGameRecord) -> [ShotType: WinRate] {
        guard let shots = game.shots else { return [:] }

        var stats: [ShotType: (total: Int, wins: Int)] = [:]

        for shot in shots where shot.associatedWithPoint {
            let current = stats[shot.type, default: (0, 0)]
            // Count all point-winning shots
            stats[shot.type] = (current.total + 1, current.wins + 1)
        }

        // Also count shots that didn't win points
        for shot in shots where !shot.associatedWithPoint && shot.isPointCandidate {
            let current = stats[shot.type, default: (0, 0)]
            stats[shot.type] = (current.total + 1, current.wins)
        }

        var winRates: [ShotType: WinRate] = [:]
        for (type, stat) in stats {
            let percentage = stat.total > 0 ? (Double(stat.wins) / Double(stat.total)) * 100 : 0
            winRates[type] = WinRate(total: stat.total, wins: stat.wins, percentage: percentage)
        }

        return winRates
    }

    // MARK: - Power Trends
    func powerStats(for shots: [StoredShot], shotType: ShotType) -> PowerStats? {
        let filtered = shots.filter { $0.type == shotType }
        guard !filtered.isEmpty else { return nil }

        let magnitudes = filtered.map { $0.absoluteMagnitude }
        let average = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let peak = magnitudes.max() ?? 0

        // Calculate standard deviation for consistency
        let variance = magnitudes.map { pow($0 - average, 2) }.reduce(0, +) / Double(magnitudes.count)
        let stdDev = sqrt(variance)

        return PowerStats(average: average, peak: peak, consistency: stdDev)
    }

    // MARK: - Rally Reaction Time
    func averageRallyReactionTime(for shots: [StoredShot]) -> TimeInterval? {
        let reactionTimes = shots.compactMap { $0.rallyReactionTime }
        guard !reactionTimes.isEmpty else { return nil }

        return reactionTimes.reduce(0, +) / Double(reactionTimes.count)
    }

    // MARK: - Full Game Analytics
    func analyze(game: WatchGameRecord) -> ShotAnalytics? {
        guard let shots = game.shots, !shots.isEmpty else { return nil }

        let distribution = shotDistribution(for: game)
        let winningShots = winRateByShotType(for: game)
        let avgReactionTime = averageRallyReactionTime(for: shots)

        var powerTrends: [ShotType: PowerStats] = [:]
        for shotType in ShotType.allCases where shotType != .unknown {
            if let stats = powerStats(for: shots, shotType: shotType) {
                powerTrends[shotType] = stats
            }
        }

        let insights = generateInsights(
            distribution: distribution,
            winningShots: winningShots,
            powerTrends: powerTrends,
            game: game
        )

        return ShotAnalytics(
            distribution: distribution,
            winningShots: winningShots,
            averageRallyReactionTime: avgReactionTime,
            powerTrend: powerTrends,
            topInsights: insights
        )
    }

    // MARK: - Insight Generation
    private func generateInsights(
        distribution: [ShotType: Int],
        winningShots: [ShotType: WinRate],
        powerTrends: [ShotType: PowerStats],
        game: WatchGameRecord
    ) -> [String] {
        var insights: [String] = []

        // 1. Winning shot analysis
        if let topWinningShot = winningShots.max(by: { $0.value.percentage < $1.value.percentage }) {
            if topWinningShot.value.percentage >= 60 {
                let displayName = topWinningShot.key.displayName(for: game.sportType, isBackhand: false)
                insights.append("\(topWinningShot.key.icon) Your \(displayName) is lethal! \(Int(topWinningShot.value.percentage))% win rate")
            }
        }

        // 2. Shot variety analysis
        let totalShots = distribution.values.reduce(0, +)
        if let touchShots = distribution[.touchShot], totalShots > 0 {
            let touchPercent = (Double(touchShots) / Double(totalShots)) * 100
            let touchName = ShotType.touchShot.displayName(for: game.sportType, isBackhand: false)
            if touchPercent < 10 {
                insights.append("🪃 Low \(touchName) usage (\(Int(touchPercent))%). Consider more soft game")
            } else if touchPercent > 40 {
                insights.append("🪃 High \(touchName) usage (\(Int(touchPercent))%). You play patient \(game.sportType)")
            }
        }

        // 3. Power consistency
        if let overheadStats = powerTrends[.overhead] {
            if overheadStats.consistency < 0.3 {
                insights.append("⚡️ Excellent overhead consistency! Keep it up")
            }
        }

        // 4. Aggression analysis
        if let powerShots = distribution[.powerShot], let overheads = distribution[.overhead], totalShots > 0 {
            let aggressionPercent = (Double(powerShots + overheads) / Double(totalShots)) * 100
            if aggressionPercent > 35 {
                insights.append("💥 Aggressive playing style (\(Int(aggressionPercent))% power shots)")
            }
        }

        // 5. Game outcome correlation
        if game.winner == "You" {
            // Find what worked
            if let bestShot = winningShots.filter({ $0.value.wins >= 3 }).max(by: { $0.value.percentage < $1.value.percentage }) {
                let displayName = bestShot.key.displayName(for: game.sportType, isBackhand: false)
                insights.append("\(bestShot.key.icon) \(displayName)s were key to your win (\(bestShot.value.wins) points)")
            }
        } else {
            // Find areas for improvement
            if let worstShot = winningShots.filter({ $0.value.total >= 3 }).min(by: { $0.value.percentage < $1.value.percentage }) {
                if worstShot.value.percentage < 40 {
                    let displayName = worstShot.key.displayName(for: game.sportType, isBackhand: false)
                    insights.append("\(worstShot.key.icon) Work on your \(displayName) - only \(Int(worstShot.value.percentage))% effective")
                }
            }
        }

        // Return top 4 insights
        return Array(insights.prefix(4))
    }

    // MARK: - Multi-Game Trends
    func analyzeTrend(games: [WatchGameRecord]) -> TrendAnalytics? {
        guard !games.isEmpty else { return nil }

        let recentGames = Array(games.prefix(10))
        var allShots: [StoredShot] = []

        for game in recentGames {
            if let shots = game.shots {
                allShots.append(contentsOf: shots)
            }
        }

        guard !allShots.isEmpty else { return nil }

        let distribution = shotDistribution(for: recentGames)
        let avgReactionTime = averageRallyReactionTime(for: allShots)

        return TrendAnalytics(
            gamesAnalyzed: recentGames.count,
            totalShots: allShots.count,
            shotDistribution: distribution,
            averageReactionTime: avgReactionTime
        )
    }
}

struct TrendAnalytics {
    let gamesAnalyzed: Int
    let totalShots: Int
    let shotDistribution: [ShotType: Int]
    let averageReactionTime: TimeInterval?
}
