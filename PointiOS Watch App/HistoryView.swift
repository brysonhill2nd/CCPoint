//
//  HistoryView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager

    var body: some View {
        NavigationStack {
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
                                NavigationLink {
                                    GameDetailView(record: record)
                                } label: {
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

                if let health = record.healthData {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                                .foregroundColor(WatchColors.loss)
                            Text("\(Int(health.averageHeartRate)) BPM")
                                .font(WatchTypography.monoLabel(9))
                                .foregroundColor(WatchColors.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundColor(WatchColors.caution)
                            Text("\(Int(health.totalCalories)) CAL")
                                .font(WatchTypography.monoLabel(9))
                                .foregroundColor(WatchColors.textSecondary)
                        }
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

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 6) {
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
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(WatchColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isWin ? WatchColors.green.opacity(0.5) : WatchColors.loss.opacity(0.5), lineWidth: 2)
                )

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
            }
            .padding(.horizontal, 4)
        }
        .background(WatchColors.background)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
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
