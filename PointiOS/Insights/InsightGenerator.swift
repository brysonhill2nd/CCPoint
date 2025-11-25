import Foundation

struct GameInsightPayload {
    let insights: HeuristicGameInsights
    let metrics: InsightMetrics
}

struct InsightMetrics {
    let servingEfficiency: Double
    let sideOutRate: Double
    let pointWinRate: Double
    let pointsWon: Int
    let totalPoints: Int
    let pointsWonOnServe: Int
    let totalServePoints: Int
    let pointsWonOnReturn: Int
    let totalReturnPoints: Int
    
    init(analysis: GameAnalysis) {
        self.servingEfficiency = analysis.servingEfficiency
        self.sideOutRate = analysis.sideOutRate
        self.pointsWonOnServe = analysis.pointsWonOnServe
        self.totalServePoints = analysis.totalServePoints
        self.pointsWonOnReturn = analysis.pointsWonOnReturn
        self.totalReturnPoints = analysis.totalReturnPoints
        
        self.totalPoints = analysis.game.points.count
        self.pointsWon = analysis.game.points.filter { $0.wonBy == .player }.count
        if totalPoints > 0 {
            self.pointWinRate = Double(pointsWon) / Double(totalPoints)
        } else {
            self.pointWinRate = 0
        }
    }
}

enum GameInsightGenerator {
    private static let engine = InsightEngine()
    
    static func generate(for record: WatchGameRecord) -> GameInsightPayload? {
        guard let data = GameInsightMapper.map(record: record) else {
            return nil
        }
        
        let analysis = GameAnalysis(game: data)
        let insights = engine.analyzeGame(data)
        let metrics = InsightMetrics(analysis: analysis)
        
        return GameInsightPayload(insights: insights, metrics: metrics)
    }
}

struct AIPerformanceOverview {
    let summary: String
    let bullets: [String]
    let gamesAnalyzed: Int
    let wins: Int
    let losses: Int
    let modelName: String
}

enum GPT4oMiniSummarizer {
    static func summarize(games: [WatchGameRecord]) -> AIPerformanceOverview? {
        guard !games.isEmpty else { return nil }
        
        let analyzed = games.compactMap { record -> (WatchGameRecord, GameInsightPayload)? in
            guard let payload = GameInsightGenerator.generate(for: record) else { return nil }
            return (record, payload)
        }
        
        let wins = games.filter { $0.winner == "You" }.count
        let losses = games.count - wins
        
        guard !analyzed.isEmpty else {
            let summary = "AI reviewed \(games.count) games (\(wins)-\(losses) record). Limited point data available, showing a record-based overview."
            let bullets = [
                "Track games with point-level data on Apple Watch to unlock serving and side-out analysis.",
                "Your record alone suggests where momentum is swinging—add rallies to sharpen these reads."
            ]
            
            return AIPerformanceOverview(
                summary: summary,
                bullets: bullets,
                gamesAnalyzed: games.count,
                wins: wins,
                losses: losses,
                modelName: "Pro"
            )
        }
        
        let combinedMetrics = analyzed.reduce((serve: 0.0, sideOut: 0.0, pointWin: 0.0, totalPoints: 0, pointsWon: 0)) { partial, entry in
            let metrics = entry.1.metrics
            var updated = partial
            updated.serve += metrics.servingEfficiency
            updated.sideOut += metrics.sideOutRate
            updated.pointWin += metrics.pointWinRate
            updated.totalPoints += metrics.totalPoints
            updated.pointsWon += metrics.pointsWon
            return updated
        }
        
        let count = Double(analyzed.count)
        let avgServe = count > 0 ? combinedMetrics.serve / count : 0
        let avgSideOut = count > 0 ? combinedMetrics.sideOut / count : 0
        let avgPointWin = count > 0 ? combinedMetrics.pointWin / count : 0
        
        let momentumCallout: String
        if avgPointWin >= 0.6 {
            momentumCallout = "kept control most of the time"
        } else if avgPointWin >= 0.5 {
            momentumCallout = "traded momentum but stayed competitive"
        } else {
            momentumCallout = "struggled to hold momentum"
        }
        
        let serveCallout: String
        if avgServe >= 0.7 {
            serveCallout = "serve was a weapon"
        } else if avgServe >= 0.55 {
            serveCallout = "serve held steady"
        } else {
            serveCallout = "returns pushed you off serve"
        }
        
        let summary = "AI reviewed \(analyzed.count) games (\(wins)-\(losses) record). You \(momentumCallout) and your \(serveCallout)."
        
        var bullets: [String] = []
        let pointWinPercent = Int((avgPointWin * 100).rounded())
        bullets.append("Point win rate averaged \(pointWinPercent)% across \(combinedMetrics.totalPoints) points.")
        
        let servePercent = Int((avgServe * 100).rounded())
        bullets.append("Serving efficiency sat at \(servePercent)%; returns converted to points \(Int((avgSideOut * 100).rounded()))% of the time.")
        
        if let standoutStrength = analyzed.compactMap({ $0.1.insights.strengths.first }).first {
            bullets.append("Biggest edge: \(standoutStrength.title) — \(standoutStrength.description)")
        } else if let firstWeakness = analyzed.compactMap({ $0.1.insights.weaknesses.first }).first {
            bullets.append("Primary focus: \(firstWeakness.title) — \(firstWeakness.description)")
        } else {
            bullets.append("Keep leaning into what worked and tighten errors late in games.")
        }
        
        return AIPerformanceOverview(
            summary: summary,
            bullets: bullets,
            gamesAnalyzed: games.count,
            wins: wins,
            losses: losses,
            modelName: "Pro"
        )
    }
}

// MARK: - Single Game LLM Insights (with heuristic fallback)
struct GameInsightLLMResult {
    let payload: GameInsightPayload
    let isFallback: Bool
    let error: String?
}

enum GPT4oMiniGameInsightService {
    static func generate(for record: WatchGameRecord) async -> GameInsightLLMResult? {
        guard let baseline = GameInsightGenerator.generate(for: record) else { return nil }
        
        guard let apiKey = OpenAIKeyProvider.key else {
            return GameInsightLLMResult(payload: baseline, isFallback: true, error: "OpenAI API key missing; showing heuristic insights.")
        }
        
        do {
            let request = try buildRequest(for: record, baseline: baseline, apiKey: apiKey)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                return GameInsightLLMResult(payload: baseline, isFallback: true, error: "AI request failed")
            }
            
            guard let parsed = parseResponse(data: data, baseline: baseline) else {
                return GameInsightLLMResult(payload: baseline, isFallback: true, error: "Could not parse AI response")
            }
            
            return GameInsightLLMResult(payload: parsed, isFallback: false, error: nil)
        } catch {
            return GameInsightLLMResult(payload: baseline, isFallback: true, error: "AI request error: \(error.localizedDescription)")
        }
    }
    
    private static func buildRequest(for record: WatchGameRecord, baseline: GameInsightPayload, apiKey: String) throws -> URLRequest {
        let metrics = baseline.metrics
        let summarySeed = baseline.insights.summary
        let strengthsSeed = baseline.insights.strengths.map { $0.title }
        let weaknessesSeed = baseline.insights.weaknesses.map { $0.title }
        
        let userContent: [String: Any] = [
            "sport": record.sportType,
            "gameType": record.gameType,
            "score": "\(record.player1Score)-\(record.player2Score)",
            "winner": record.winner ?? "Unknown",
            "servingEfficiency": metrics.servingEfficiency,
            "sideOutRate": metrics.sideOutRate,
            "pointWinRate": metrics.pointWinRate,
            "points": metrics.totalPoints,
            "strength_hints": strengthsSeed,
            "weakness_hints": weaknessesSeed,
            "seed_summary": summarySeed
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.4,
            "max_tokens": 220,
            "messages": [
                [
                    "role": "system",
                    "content": """
You are a racket-sports performance analyst. Return JSON only: {"summary": "...", "recommendation": "...", "strengths": ["..."], "weaknesses": ["..."], "tone": "dominant|clutch|competitive|rough"}.
Keep summary under 2 sentences; limit strengths/weaknesses to 2 each.
"""
                ],
                [
                    "role": "user",
                    "content": jsonString(from: userContent)
                ]
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data
        return request
    }
    
    private static func parseResponse(data: Data, baseline: GameInsightPayload) -> GameInsightPayload? {
        struct ChatCompletion: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        
        guard
            let completion = try? JSONDecoder().decode(ChatCompletion.self, from: data),
            let content = completion.choices.first?.message.content,
            let contentData = content.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)
        else { return nil }
        
        struct Shape: Decodable {
            let summary: String
            let recommendation: String
            let strengths: [String]
            let weaknesses: [String]
            let tone: String?
        }
        
        guard let decoded = try? JSONDecoder().decode(Shape.self, from: contentData) else { return nil }
        
        let strengths = decoded.strengths.map { InsightDetail(title: $0, description: $0, icon: "💡", data: "") }
        let weaknesses = decoded.weaknesses.map { InsightDetail(title: $0, description: $0, icon: "⚠️", data: "") }
        let tone = InsightTone(from: decoded.tone) ?? baseline.insights.tone
        
        let insights = HeuristicGameInsights(
            summary: decoded.summary,
            strengths: strengths.isEmpty ? baseline.insights.strengths : strengths,
            weaknesses: weaknesses.isEmpty ? baseline.insights.weaknesses : weaknesses,
            recommendation: decoded.recommendation,
            tone: tone
        )
        
        return GameInsightPayload(insights: insights, metrics: baseline.metrics)
    }
    
    private static func jsonString(from object: Any) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\(object)"
    }
}

// MARK: - OpenAI Key Provider
enum OpenAIKeyProvider {
    static var key: String? {
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = UserDefaults.standard.string(forKey: "OPENAI_API_KEY"), !key.isEmpty {
            return key
        }
        return nil
    }
}

private extension InsightTone {
    init?(from raw: String?) {
        guard let raw = raw?.lowercased() else { return nil }
        switch raw {
        case "dominant": self = .dominant
        case "clutch": self = .clutch
        case "competitive": self = .competitive
        case "rough": self = .rough
        default: return nil
        }
    }
}
