//
//  HistoryView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @State private var selectedGame: GameRecord? = nil
    @State private var showingInsights = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Clear all button at the top - Swiss style
                if !historyManager.history.isEmpty {
                    Button(action: { historyManager.clearHistory() }) {
                        Text("CLEAR ALL")
                            .font(WatchTypography.monoLabel(9))
                            .foregroundColor(WatchColors.loss)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }

                if historyManager.history.isEmpty {
                    // Empty state - Swiss style
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 28))
                            .foregroundColor(WatchColors.textTertiary)

                        Text("NO GAMES YET")
                            .font(WatchTypography.monoLabel(11))
                            .foregroundColor(WatchColors.textSecondary)

                        Text("Play a game to see your history")
                            .font(WatchTypography.caption())
                            .foregroundColor(WatchColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(historyManager.history) { record in
                            Button(action: {
                                selectedGame = record
                                showingInsights = true
                            }) {
                                HistoryRowView(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Lazy-load history only when view is shown for better app launch performance
            historyManager.ensureLoaded()
        }
        .fullScreenCover(isPresented: $showingInsights) {
            if let game = selectedGame {
                NavigationStack {
                    GameDetailView(record: game)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingInsights = false
                                }
                                .foregroundColor(WatchColors.green)
                            }
                        }
                }
                .background(WatchColors.background)
            }
        }
    }
}

struct HistoryRowView: View {
    let record: GameRecord

    private var isWin: Bool {
        record.winner == "You"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Date and Time - Swiss style
                HStack {
                    Text(record.date, style: .date)
                        .font(WatchTypography.monoLabel(9))
                        .foregroundColor(WatchColors.textTertiary)
                    Spacer()
                    Text(record.date, style: .time)
                        .font(WatchTypography.monoLabel(9))
                        .foregroundColor(WatchColors.textTertiary)
                }

                // Sport and Score - Swiss style
                HStack {
                    HStack(spacing: 4) {
                        Text(record.sportAbbreviation)
                            .font(WatchTypography.monoLabel(10))
                            .foregroundColor(WatchColors.textSecondary)
                        Text(record.gameType.uppercased())
                            .font(WatchTypography.monoLabel(10))
                            .foregroundColor(WatchColors.textPrimary)
                    }
                    Spacer()
                    Text(record.scoreDisplay)
                        .font(WatchTypography.headline())
                        .foregroundColor(WatchColors.textPrimary)
                }

                // Duration and Result - Swiss style
                HStack {
                    Text(record.elapsedTimeDisplay)
                        .font(WatchTypography.monoLabel(9))
                        .foregroundColor(WatchColors.textTertiary)
                    Spacer()
                    if let winner = record.winner {
                        WatchBadge(
                            text: winner == "You" ? "WIN" : "LOSS",
                            isWin: winner == "You"
                        )
                    } else {
                        Text("INCOMPLETE")
                            .font(WatchTypography.monoLabel(9))
                            .foregroundColor(WatchColors.caution)
                    }
                }

                // Game count if multi-game match
                if record.player1GamesWon > 0 || record.player2GamesWon > 0 {
                    Text("GAMES \(record.gameCountDisplay)")
                        .font(WatchTypography.monoLabel(9))
                        .foregroundColor(WatchColors.textTertiary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(WatchColors.textTertiary)
                .padding(.trailing, 8)
        }
        .background(WatchColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(WatchColors.borderMuted, lineWidth: 1)
        )
    }
}

struct GameDetailView: View {
    let record: GameRecord

    private var isWin: Bool {
        record.winner == "You"
    }

    // Compute insights from events
    private var insights: WatchGameInsights? {
        guard let events = record.events, !events.isEmpty else { return nil }
        return WatchGameInsights(events: events)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header Card - Swiss style
                VStack(spacing: 8) {
                    Text("\(record.sportType.uppercased()) \(record.gameType.uppercased())")
                        .font(WatchTypography.monoLabel(10))
                        .tracking(1)
                        .foregroundColor(WatchColors.textSecondary)

                    Text(record.scoreDisplay)
                        .font(WatchTypography.scoreLarge())
                        .foregroundColor(WatchColors.textPrimary)

                    if let winner = record.winner {
                        WatchBadge(
                            text: winner == "You" ? "WIN" : "LOSS",
                            isWin: winner == "You"
                        )
                    }
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(WatchColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isWin ? WatchColors.green.opacity(0.5) : WatchColors.loss.opacity(0.5), lineWidth: 2)
                )

                // Quick Stats - Serve Performance
                if let insights = insights {
                    HStack(spacing: 8) {
                        // Your Serve %
                        VStack(spacing: 4) {
                            Text("\(insights.yourServeWinPercent)%")
                                .font(WatchTypography.headline())
                                .foregroundColor(insights.yourServeWinPercent >= 60 ? WatchColors.green : WatchColors.textPrimary)
                            Text("YOUR SERVE")
                                .font(WatchTypography.monoLabel(7))
                                .foregroundColor(WatchColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Best Streak
                        VStack(spacing: 4) {
                            Text("\(insights.longestYourRun)")
                                .font(WatchTypography.headline())
                                .foregroundColor(WatchColors.green)
                            Text("BEST RUN")
                                .font(WatchTypography.monoLabel(7))
                                .foregroundColor(WatchColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Lead Changes
                        VStack(spacing: 4) {
                            Text("\(insights.leadChanges)")
                                .font(WatchTypography.headline())
                                .foregroundColor(WatchColors.textPrimary)
                            Text("LEAD CHG")
                                .font(WatchTypography.monoLabel(7))
                                .foregroundColor(WatchColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Health Data Section
                if let health = record.healthData {
                    HStack(spacing: 8) {
                        VStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(WatchColors.loss)
                            Text("\(Int(health.averageHeartRate))")
                                .font(WatchTypography.headline())
                                .foregroundColor(WatchColors.textPrimary)
                            Text("BPM")
                                .font(WatchTypography.monoLabel(7))
                                .foregroundColor(WatchColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(WatchColors.caution)
                            Text("\(Int(health.totalCalories))")
                                .font(WatchTypography.headline())
                                .foregroundColor(WatchColors.textPrimary)
                            Text("CAL")
                                .font(WatchTypography.monoLabel(7))
                                .foregroundColor(WatchColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(WatchColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Details - Swiss style
                VStack(spacing: 8) {
                    DetailRow(label: "DATE", value: record.date.formatted(date: .abbreviated, time: .shortened))
                    DetailRow(label: "DURATION", value: record.elapsedTimeDisplay)

                    if record.player1GamesWon > 0 || record.player2GamesWon > 0 {
                        DetailRow(label: "SETS", value: record.gameCountDisplay)
                    }
                }
                .padding(10)
                .background(WatchColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Set History Section
                if let sets = record.setHistory, !sets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SET HISTORY")
                            .font(WatchTypography.monoLabel(8))
                            .tracking(1)
                            .foregroundColor(WatchColors.textSecondary)

                        ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(WatchTypography.caption())
                                    .foregroundColor(WatchColors.textTertiary)
                                Spacer()
                                if let tb = set.tiebreakScore {
                                    Text("\(set.player1Games)-\(set.player2Games) (\(tb.0)-\(tb.1))")
                                        .font(WatchTypography.subheadline())
                                        .foregroundColor(WatchColors.textPrimary)
                                } else {
                                    Text("\(set.player1Games)-\(set.player2Games)")
                                        .font(WatchTypography.subheadline())
                                        .foregroundColor(WatchColors.textPrimary)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(WatchColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 4)
        }
        .background(WatchColors.background)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Watch Game Insights (lightweight version)
struct WatchGameInsights {
    let events: [GameEventData]

    var yourServeWinPercent: Int {
        let yourServeEvents = events.filter { $0.servingPlayer == "player1" }
        guard !yourServeEvents.isEmpty else { return 0 }
        let won = yourServeEvents.filter { $0.scoringPlayer == "player1" }.count
        return Int(Double(won) / Double(yourServeEvents.count) * 100)
    }

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
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(WatchTypography.monoLabel(9))
                .tracking(0.5)
                .foregroundColor(WatchColors.textTertiary)
            Spacer()
            Text(value)
                .font(WatchTypography.subheadline())
                .foregroundColor(WatchColors.textPrimary)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let mockHistory = HistoryManager()
        
        NavigationStack {
            HistoryView()
                .environmentObject(mockHistory)
        }
    }
}
