
import Foundation
import Combine

struct XPReward {
    let total: Int
    let breakdown: [String: Int]
    let leveledUp: Bool
}

final class XPManager: ObservableObject {
    static let shared = XPManager()
    private let totalXPKey = "xp.total"
    private let levelKey = "xp.level"
    private let defaults = UserDefaults.standard

    @Published private(set) var totalXP: Int
    @Published private(set) var level: Int
    @Published private(set) var xpIntoLevel: Int = 0
    @Published private(set) var xpForNextLevel: Int = 100

    private init() {
        let storedXP = defaults.integer(forKey: totalXPKey)
        var storedLevel = defaults.integer(forKey: levelKey)
        if storedLevel < 1 { storedLevel = 1 }
        self.totalXP = storedXP
        self.level = storedLevel
        recalcProgress()
    }

    func awardXP(for game: WatchGameRecord) -> XPReward {
        var total = 0
        var breakdown: [String: Int] = [:]

        total += 50
        breakdown["Game Completed"] = 50

        if game.winner == "You" {
            total += 25
            breakdown["Victory Bonus"] = 25
        }

        if let events = game.events, !events.isEmpty {
            let comeback = events.contains { event in
                event.player2Score - event.player1Score >= 4 && game.winner == "You"
            }
            if comeback {
                total += 20
                breakdown["Comeback"] = 20
            }
            let rallyBonus = calculateRallyBonus(from: events)
            if rallyBonus > 0 {
                total += rallyBonus
                breakdown["Long Rallies"] = rallyBonus
            }
        }

        if game.player1Score >= 11 && game.player1Score - game.player2Score >= 5 {
            total += 20
            breakdown["Dominant Win"] = 20
        }

        if game.elapsedTime > 900 {
            total += 10
            breakdown["Endurance"] = 10
        }

        let leveled = addXP(total)
        return XPReward(total: total, breakdown: breakdown, leveledUp: leveled)
    }

    private func calculateRallyBonus(from events: [GameEventData]) -> Int {
        var streak = 0
        var bonus = 0
        for event in events {
            if event.isServePoint && (event.player1Score + event.player2Score) % 2 == 0 {
                streak += 1
                if streak >= 3 {
                    bonus += 5
                }
            } else {
                streak = 0
            }
        }
        return min(bonus, 40)
    }

    private func addXP(_ amount: Int) -> Bool {
        guard amount > 0 else { return false }
        totalXP += amount
        defaults.set(totalXP, forKey: totalXPKey)
        var leveled = false
        while totalXP >= cumulativeXP(for: level + 1) {
            level += 1
            leveled = true
        }
        defaults.set(level, forKey: levelKey)
        recalcProgress()
        NotificationCenter.default.post(name: .xpDidUpdate, object: nil)
        return leveled
    }

    private func recalcProgress() {
        let currentThreshold = cumulativeXP(for: level)
        let nextThreshold = cumulativeXP(for: level + 1)
        xpIntoLevel = totalXP - currentThreshold
        xpForNextLevel = nextThreshold - currentThreshold
    }

    private func cumulativeXP(for targetLevel: Int) -> Int {
        var sum = 0
        var requirement = 100
        var currentLevel = 1
        while currentLevel < targetLevel {
            sum += requirement
            requirement = Int(Double(requirement) * 1.5)
            currentLevel += 1
        }
        return sum
    }
}

extension Notification.Name {
    static let xpDidUpdate = Notification.Name("xpDidUpdate")
}
