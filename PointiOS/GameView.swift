// GameView.swift
import SwiftUI
import LucideIcons

struct GameView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @StateObject private var locationDataManager = LocationDataManager.shared
    @State private var showingSessionShare = false
    @State private var showingLocationPicker = false
    @State private var selectedGameForDetail: WatchGameRecord? = nil
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingProSheet = false
    @State private var aiOverview: AIPerformanceOverview?
    @State private var aiError: String?
    @State private var aiLoading = false
    @State private var performanceStats: PerformanceStats = .empty

    var todaysSession: SessionSummary {
        let todaysGames = watchConnectivity.todaysGames
        let wins = todaysGames.filter { $0.winner == "You" }.count
        let totalTime = todaysGames.reduce(0) { $0 + $1.elapsedTime }

        let totalCalories = todaysGames.compactMap { $0.healthData?.totalCalories }.reduce(0, +)
        let heartRates = todaysGames.compactMap { $0.healthData?.averageHeartRate }
        let avgHeartRate = heartRates.isEmpty ? 0 : heartRates.reduce(0, +) / Double(heartRates.count)

        return SessionSummary(
            date: Date(),
            location: locationDataManager.currentLocation,
            gamesPlayed: todaysGames.count,
            gamesWon: wins,
            totalTime: totalTime,
            calories: totalCalories,
            avgHeartRate: avgHeartRate
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Section - Pinned to top
                VStack(spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today")
                                .font(.custom("New York", size: 34))
                                .foregroundColor(.primary)

                            Text(Date(), style: .date)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .padding(.top, 1)
                .background(Color(.systemBackground))

                ScrollView {
                    VStack(spacing: 10) {
                    // Today's Session Card
                    if !watchConnectivity.todaysGames.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            // Card Header
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Today's Session")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)

                                    Button(action: { showingLocationPicker = true }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                            Text(locationDataManager.currentLocation)
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Spacer()
                                
                                HStack(spacing: 16) {
                                    // Manual sync button
                                    Button(action: {
                                        WatchConnectivityManager.shared.manualCheckForPendingData()
                                        Task {
                                            await WatchConnectivityManager.shared.refreshFromCloud()
                                        }
                                    }) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 20))
                                            .foregroundColor(.accentColor)
                                    }

                                    Button(action: { showingSessionShare = true }) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 20))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .padding(16)
                            
                            // Stats Section
                            VStack(spacing: 12) {
                                // Games Won
                                HStack {
                                    HStack(spacing: 12) {
                                        Text("🏆")
                                            .font(.system(size: 24))
                                        Text("Games Won")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(todaysSession.gamesWon) of \(todaysSession.gamesPlayed)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                
                                // Time Played
                                HStack {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.accentColor)
                                        Text("Time Played")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatTime(todaysSession.totalTime))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                
                                // Calories and Heart Rate Row
                                HStack {
                                    // Calories
                                    HStack(spacing: 8) {
                                        Text("🔥")
                                            .font(.system(size: 24))
                                        if todaysSession.calories > 0 {
                                            Text("\(Int(todaysSession.calories))")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Heart Rate
                                    HStack(spacing: 8) {
                                        Text("❤️")
                                            .font(.system(size: 24))
                                        if todaysSession.avgHeartRate > 0 {
                                            Text("\(Int(todaysSession.avgHeartRate))")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.primary)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .padding(.top, -5)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                        .padding(.horizontal, 16)
                    }
                    
                    // Today's Games Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Games")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        // Games List
                        if watchConnectivity.todaysGames.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "figure.pickleball")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("No Games Today")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Start playing on your Apple Watch\nto track today's games")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal, 20)
                        } else {
                            if watchConnectivity.todaysGames.count > 3 {
                                TabView {
                                    ForEach(Array(gamePages().enumerated()), id: \.offset) { _, page in
                                        VStack(spacing: 12) {
                                            ForEach(page) { game in
                                                GameRow(game: game) {
                                                    guard pro.isPro else {
                                                        showingProSheet = true
                                                        return
                                                    }
                                                    if let events = game.events, !events.isEmpty {
                                                        selectedGameForDetail = game
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                                .frame(height: 240)
                                .tabViewStyle(.page(indexDisplayMode: .never))
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(watchConnectivity.todaysGames) { game in
                                        GameRow(game: game) {
                                            guard pro.isPro else {
                                                showingProSheet = true
                                                return
                                            }
                                            if let events = game.events, !events.isEmpty {
                                                selectedGameForDetail = game
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    aiOverviewSection
                    
                        Spacer()
                            .frame(height: 100)
                    }
                }
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSessionShare) {
            SessionShareView(sessionData: todaysSession)
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView()
                .environmentObject(locationDataManager)
        }
        .sheet(item: $selectedGameForDetail) { game in
            GameDetailView(game: game)
        }
        .sheet(isPresented: $showingProSheet) {
            UpgradeView()
        }
        .onAppear {
            // Delay AI load slightly to prioritize initial UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                loadAIPerformanceOverview()
            }
        }
        .onReceive(watchConnectivity.$receivedGames) { _ in
            performanceStats = PerformanceStatsBuilder.build(from: watchConnectivity.receivedGames)
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func gamePages() -> [[WatchGameRecord]] {
        let games = watchConnectivity.todaysGames
        var result: [[WatchGameRecord]] = []
        var index = 0
        while index < games.count {
            let end = min(index + 3, games.count)
            result.append(Array(games[index..<end]))
            index = end
        }
        return result
    }
    
    @ViewBuilder
    private var aiOverviewSection: some View {
        if pro.isPro {
            AIPerformanceOverviewSection(
                overview: aiOverview,
                stats: performanceStats,
                isLoading: aiLoading,
                error: aiError,
                onRetry: loadAIPerformanceOverview
            )
            .padding(.horizontal, 20)
        } else {
            LockedFeatureCard(
                title: "AI Performance Overview",
                description: "Upgrade to Point Pro to unlock premium insights, charts, and recommendations."
            ) {
                showingProSheet = true
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func loadAIPerformanceOverview() {
        aiError = nil
        aiOverview = nil
        performanceStats = PerformanceStatsBuilder.build(from: watchConnectivity.receivedGames)
        
        guard !watchConnectivity.todaysGames.isEmpty else { return }
        aiLoading = true
        
        Task {
            let result = await AIPerformanceOverviewService.shared.summarize(games: watchConnectivity.todaysGames)
            await MainActor.run {
                aiLoading = false
                aiOverview = result.overview
                aiError = result.error
            }
        }
    }
}

// Game Row (required for the view to compile)
struct GameRow: View {
    let game: WatchGameRecord
    let onTap: () -> Void
    
    var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: game.date, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Sport emoji
                Text(game.sportEmoji)
                    .font(.system(size: 32))
                
                // Game details
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(game.sportType) \(game.gameType)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(timeString)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Score and result
                VStack(alignment: .trailing, spacing: 4) {
                    Text(game.scoreDisplay)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)

                    if let winner = game.winner {
                        HStack(spacing: 4) {
                            Image(icon: winner == "You" ? .trophy : .x)
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundColor(winner == "You" ? .green : .red)

                            Text(winner == "You" ? "Won" : "Lost")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(winner == "You" ? .green : .red)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - AI Performance Overview (Spec Implementation)
struct AIPerformanceOverviewSection: View {
    let overview: AIPerformanceOverview?
    let stats: PerformanceStats
    let isLoading: Bool
    let error: String?
    let onRetry: () -> Void
    
    private var tipText: String {
        if let first = overview?.bullets.first {
            return first
        }
        if let summary = overview?.summary {
            return summary
        }
        return generateAITip(stats: stats)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Performance Overview")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            if isLoading {
                AIPerformanceLoadingCard()
            } else {
                AIPerformanceSimpleCard(
                    stats: stats,
                    tip: tipText,
                    overview: overview,
                    error: error
                )
            }
            
            if let error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        onRetry()
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
            }
        }
    }
}

struct AIPerformanceSimpleCard: View {
    let stats: PerformanceStats
    let tip: String
    let overview: AIPerformanceOverview?
    let error: String?
    
    private var rating: (String, String) {
        calculateOverallPerformance(stats: stats)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            OverallPerformanceHeader(rating: rating.0, emoji: rating.1)
            
            VStack(spacing: 16) {
                MetricProgressRow(title: "Win Rate (Last 7 Days)",
                                  percent: stats.winRatePercent,
                                  color: .green)
                MetricProgressRow(title: "Serving Efficiency",
                                  percent: stats.servingPercent,
                                  color: .blue)
                MetricProgressRow(title: "Side-Out Rate",
                                  percent: stats.sideOutPercent,
                                  color: .purple)
            }
            
            if let overview {
                Text(overview.summary)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            AITipCard(tip: tip)
            
            HStack(spacing: 12) {
                SummaryStatCard(value: "\(stats.gamesThisWeek)",
                                label: "Games This Week")
                SummaryStatCard(value: stats.formattedTimePlayed,
                                label: "Time Played")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Subcomponents
private struct OverallPerformanceHeader: View {
    let rating: String
    let emoji: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text("📊")
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Performance")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text(rating)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(emoji)
                .font(.system(size: 24))
        }
        .padding(.bottom, 8)
    }
}

private struct MetricProgressRow: View {
    let title: String
    let percent: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(max(0, min(100, percent)))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 999)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(100, percent))) / 100, height: 8)
                        .animation(.easeOut(duration: 0.3), value: percent)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct AITipCard: View {
    let tip: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("💡")
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Tip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                Text(tip)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct SummaryStatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 1)
                )
        )
    }
}


struct AIPerformanceLoadingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 18)
                Spacer()
            }
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(height: 14)
            
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                }
            }
        }
        .redacted(reason: .placeholder)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Stats + Helpers
struct PerformanceStats {
    let winRate: Double
    let servingEfficiency: Double
    let sideOutRate: Double
    let gamesThisWeek: Int
    let timePlayedMinutes: Int
    let last7GamesCount: Int
    
    static let empty = PerformanceStats(
        winRate: 0,
        servingEfficiency: 0,
        sideOutRate: 0,
        gamesThisWeek: 0,
        timePlayedMinutes: 0,
        last7GamesCount: 0
    )
    
    var winRatePercent: Int { Int((winRate * 100).rounded()) }
    var servingPercent: Int { Int((servingEfficiency * 100).rounded()) }
    var sideOutPercent: Int { Int((sideOutRate * 100).rounded()) }
    
    var formattedTimePlayed: String {
        if timePlayedMinutes < 60 {
            return "\(timePlayedMinutes)m"
        }
        let hours = Double(timePlayedMinutes) / 60.0
        if hours < 10 {
            return String(format: "%.1fh", hours)
        } else {
            return "\(Int(hours))h"
        }
    }
}

enum PerformanceStatsBuilder {
    static func build(from games: [WatchGameRecord]) -> PerformanceStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        
        let last7 = games.filter { calendar.startOfDay(for: $0.date) >= sevenDaysAgo }
        let wins = last7.filter { $0.winner == "You" }.count
        let winRate = last7.isEmpty ? 0 : Double(wins) / Double(last7.count)
        
        let metrics = last7.compactMap { GameInsightGenerator.generate(for: $0)?.metrics }
        let servingEff = metrics.isEmpty ? 0 : metrics.map { $0.servingEfficiency }.reduce(0, +) / Double(metrics.count)
        let sideOut = metrics.isEmpty ? 0 : metrics.map { $0.sideOutRate }.reduce(0, +) / Double(metrics.count)
        
        // Week aggregates
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let thisWeek = games.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= startOfWeek && day <= today
        }
        let timeMinutes = Int(thisWeek.reduce(0) { $0 + $1.elapsedTime } / 60)
        
        return PerformanceStats(
            winRate: winRate,
            servingEfficiency: servingEff,
            sideOutRate: sideOut,
            gamesThisWeek: thisWeek.count,
            timePlayedMinutes: timeMinutes,
            last7GamesCount: last7.count
        )
    }
}

private func calculateOverallPerformance(stats: PerformanceStats) -> (String, String) {
    let winRateWeight = 0.5
    let servingWeight = 0.25
    let sideOutWeight = 0.25
    
    let overallScore = (stats.winRate * winRateWeight) +
    (stats.servingEfficiency * servingWeight) +
    (stats.sideOutRate * sideOutWeight)
    
    if overallScore >= 0.60 {
        return ("Strong", "💪")
    } else if overallScore >= 0.45 {
        return ("Improving", "📈")
    } else {
        return ("Needs Work", "🎯")
    }
}

private func generateAITip(stats: PerformanceStats) -> String {
    let servingEff = stats.servingEfficiency
    let sideOutRate = stats.sideOutRate
    let winRate = stats.winRate
    
    let metrics: [(name: String, value: Double)] = [
        ("serving", servingEff),
        ("sideOut", sideOutRate),
        ("winRate", winRate)
    ]
    
    let lowestMetric = metrics.min(by: { $0.value < $1.value })!
    
    switch lowestMetric.name {
    case "serving":
        if servingEff < 0.50 {
            return "Work on holding serve more consistently. Vary between deep and short targets."
        } else if servingEff < 0.60 {
            return "Improve serving efficiency by aiming at the weaker returner more often."
        }
    case "sideOut":
        if sideOutRate < 0.40 {
            return "Focus on aggressive returns to create more side-out chances."
        } else if sideOutRate < 0.50 {
            return "Tighten return consistency—deep returns buy time to get to the net."
        }
    case "winRate":
        if winRate < 0.40 {
            return "Review point-by-point trends to spot runs in close games."
        } else if winRate < 0.50 {
            return "You're close—limit opponent runs to 3 points or less."
        }
    default:
        break
    }
    
    if servingEff >= 0.70 && winRate < 0.60 {
        return "Your serving is strong. Focus on maintaining leads to improve win rate."
    }
    
    if sideOutRate >= 0.60 && servingEff < 0.65 {
        return "Excellent return game—now convert more on serve to close sets faster."
    }
    
    if winRate >= 0.65 && servingEff >= 0.65 && sideOutRate >= 0.55 {
        return "Outstanding performance—keep momentum and stay consistent."
    }
    
    if abs(servingEff - sideOutRate) < 0.10 {
        return "Balanced game—small gains in each area will compound."
    }
    
    return "Play more matches to unlock deeper AI insights based on your trends."
}
