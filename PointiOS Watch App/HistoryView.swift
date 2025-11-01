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
                // Clear all button at the top
                if !historyManager.history.isEmpty {
                    Button("Clear All History") {
                        historyManager.clearHistory() // Fixed: Added parentheses
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.bottom, 10)
                }
                
                if historyManager.history.isEmpty {
                    VStack(spacing: 15) {
                        Text("No games recorded yet.")
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        Text("Play a game to see your history here!")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(historyManager.history) { record in
                            HistoryRowView(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedGame = record
                                    showingInsights = true
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingInsights) {
            if let game = selectedGame {
                NavigationStack {
                    GameDetailView(record: game)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingInsights = false
                                }
                            }
                        }
                }
            }
        }
    }
}

struct HistoryRowView: View {
    let record: GameRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Date and Time
                HStack {
                    Text(record.date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(record.date, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Sport Abbreviation, Game Type and Score
                HStack {
                    HStack(spacing: 4) {
                        Text(record.sportAbbreviation)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text(record.gameType)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text(record.scoreDisplay)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                // Duration and Winner
                HStack {
                    Text("Duration: \(record.elapsedTimeDisplay)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let winner = record.winner {
                        Text(winner == "You" ? "Won" : "Lost")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(winner == "You" ? .green : .red)
                    } else {
                        Text("Incomplete")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Game count if multi-game match
                if record.player1GamesWon > 0 || record.player2GamesWon > 0 {
                    Text("Games: \(record.gameCountDisplay)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            
            // Chevron to indicate tappable
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct GameDetailView: View {
    let record: GameRecord
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .center, spacing: 10) {
                    Text("\(record.sportAbbreviation) - \(record.sportType) \(record.gameType)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(record.scoreDisplay)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    if let winner = record.winner {
                        Text(winner == "You" ? "Victory! 🎉" : "Defeat 😔")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(winner == "You" ? .green : .red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Details
                VStack(alignment: .leading, spacing: 15) {
                    DetailRow(label: "Sport", value: record.sportType)
                    DetailRow(label: "Format", value: record.gameType)
                    DetailRow(label: "Date", value: record.date.formatted(date: .abbreviated, time: .shortened))
                    DetailRow(label: "Duration", value: record.elapsedTimeDisplay)
                    DetailRow(label: "Match Format", value: record.matchFormatDescription)
                    
                    if record.player1GamesWon > 0 || record.player2GamesWon > 0 {
                        DetailRow(label: "Games Won", value: record.gameCountDisplay)
                    }
                    
                    // Health Data Section (if available)
                    if let health = record.healthData {
                        Divider()
                        
                        Text("Health Stats")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        DetailRow(label: "Avg Heart Rate", value: "\(Int(health.averageHeartRate)) bpm")
                        DetailRow(label: "Calories Burned", value: "\(Int(health.totalCalories)) cal")
                    }
                    
                    // Set History Section (if available)
                    if let sets = record.setHistory, !sets.isEmpty {
                        Divider()
                        
                        Text("Set History")
                            .font(.headline)
                            .padding(.top, 10)
                        
                        ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                            HStack {
                                Text("Set \(index + 1):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let tb = set.tiebreakScore {
                                    Text("\(set.player1Games)-\(set.player2Games) (\(tb.0)-\(tb.1))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                } else {
                                    Text("\(set.player1Games)-\(set.player2Games)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Game Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
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
