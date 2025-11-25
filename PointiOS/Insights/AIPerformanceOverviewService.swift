import Foundation

struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

struct AIPerformanceOverviewResult {
    let overview: AIPerformanceOverview?
    let error: String?
}

final class AIPerformanceOverviewService {
    static let shared = AIPerformanceOverviewService()
    
    private let session: URLSession
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o-mini"
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func summarize(games: [WatchGameRecord]) async -> AIPerformanceOverviewResult {
        guard !games.isEmpty else {
            return AIPerformanceOverviewResult(overview: nil, error: "No games to summarize")
        }
        
        guard let apiKey = OpenAIKeyProvider.key else {
            let fallback = GPT4oMiniSummarizer.summarize(games: games)
            return AIPerformanceOverviewResult(
                overview: fallback,
                error: "OpenAI API key missing. Showing heuristic summary."
            )
        }
        
        do {
            let request = try await buildRequest(for: games, apiKey: apiKey)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugPrint("AIPerf: Invalid response")
                return fallbackResult(games: games, message: "Invalid response")
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? "<no body>"
                debugPrint("AIPerf: HTTP \(httpResponse.statusCode) body: \(body)")
                let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                return fallbackResult(games: games, message: "API error: \(message)")
            }
            
            let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            guard let content = completion.choices.first?.message.content else {
                let bodyString = String(data: data, encoding: .utf8) ?? "<no body>"
                debugPrint("AIPerf: Empty AI response body: \(bodyString)")
                return fallbackResult(games: games, message: "Empty AI response")
            }
            
            if let parsed = parseOverview(from: content, games: games) {
                return AIPerformanceOverviewResult(overview: parsed, error: nil)
            } else {
                debugPrint("AIPerf: Parse fail content: \(content)")
                return fallbackResult(games: games, message: "Could not parse AI response")
            }
        } catch {
            debugPrint("AIPerf: Request failed: \(error.localizedDescription)")
            return fallbackResult(games: games, message: "Request failed: \(error.localizedDescription)")
        }
    }
    
    private func fallbackResult(games: [WatchGameRecord], message: String) -> AIPerformanceOverviewResult {
        let fallback = GPT4oMiniSummarizer.summarize(games: games)
        let friendly = "AI service is unavailable right now. Showing fallback insights."
        return AIPerformanceOverviewResult(overview: fallback, error: friendly)
    }
    
    private func buildRequest(for games: [WatchGameRecord], apiKey: String) async throws -> URLRequest {
        let payload = buildPromptPayload(for: games)
        let requestBody: [String: Any] = [
            "model": model,
            "temperature": 0.4,
            "max_tokens": 280,
            "messages": [
                [
                    "role": "system",
                    "content": "You summarize racket sports matches (pickleball, tennis, padel). Return concise JSON: {\"summary\": \"string\", \"bullets\": [\"string\", ...], \"wins\": number, \"losses\": number}. Keep summary under 3 short sentences and bullets under 3 items."
                ],
                [
                    "role": "user",
                    "content": payload
                ]
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data
        return request
    }
    
    private func buildPromptPayload(for games: [WatchGameRecord]) -> String {
        let mapped = games.map { game -> [String: Any] in
            var dict: [String: Any] = [
                "sport": game.sportType,
                "type": game.gameType,
                "score": "\(game.player1Score)-\(game.player2Score)",
                "winner": game.winner ?? "Unknown",
                "duration_seconds": Int(game.elapsedTime),
                "date": ISO8601DateFormatter().string(from: game.date)
            ]
            
            if let health = game.healthData {
                dict["avg_hr"] = Int(health.averageHeartRate)
                dict["calories"] = Int(health.totalCalories)
            }
            
            if let events = game.events {
                dict["points"] = events.count
            }
            
            return dict
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: mapped, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return "Summarize these games: \(json)"
        }
        
        return "Summarize these games totaling \(games.count) entries."
    }
    
    private func parseOverview(from content: String, games: [WatchGameRecord]) -> AIPerformanceOverview? {
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = cleaned.data(using: .utf8) ?? Data()
        
        struct ResponseShape: Decodable {
            let summary: String
            let bullets: [String]
            let wins: Int?
            let losses: Int?
        }
        
        if let decoded = try? JSONDecoder().decode(ResponseShape.self, from: data) {
            let wins = decoded.wins ?? games.filter { $0.winner == "You" }.count
            let losses = decoded.losses ?? games.count - wins
            return AIPerformanceOverview(
                summary: decoded.summary,
                bullets: Array(decoded.bullets.prefix(3)),
                gamesAnalyzed: games.count,
                wins: wins,
                losses: losses,
                modelName: model
            )
        }
        
        return nil
    }
    
    
}
