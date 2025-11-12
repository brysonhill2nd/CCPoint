//
//  HistoryView.swift
//  PointiOS
//
//  Created by Bryson Hill II on 8/6/25.
//

// HistoryView.swift - Corrected
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedSport: SportFilter
    @State private var showingDeleteConfirmation = false
    @State private var selectedGamesForDeletion: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingClearAllConfirmation = false
    
    init(initialFilter: SportFilter = .all) {
        _selectedSport = State(initialValue: initialFilter)
    }
    
    var filteredGames: [WatchGameRecord] {
        watchConnectivity.games(for: selectedSport)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Sport Filter Pills (Assuming this is defined elsewhere)
                        // SportFilterPills(selectedSport: $selectedSport)
                        //     .padding(.horizontal, 20)
                        //     .padding(.top, 20)
                        //     .padding(.bottom, 24)
                        
                        // Stats Summary
                        HistoryStatsCard(games: filteredGames)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        
                        // Games List
                        if filteredGames.isEmpty {
                            EmptyHistoryView(selectedSport: selectedSport)
                                .padding(.top, 60)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                // Section Header
                                HStack {
                                    Text("\(filteredGames.count) Games")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if isSelectionMode {
                                        Button("Cancel") {
                                            withAnimation {
                                                isSelectionMode = false
                                                selectedGamesForDeletion.removeAll()
                                            }
                                        }
                                        .foregroundColor(.accentColor)
                                    } else {
                                        Button("Select") {
                                            withAnimation {
                                                isSelectionMode = true
                                            }
                                        }
                                        .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                // Games
                                ForEach(filteredGames) { game in
                                    HistoryGameRow(
                                        game: game,
                                        isSelected: selectedGamesForDeletion.contains(game.id),
                                        isSelectionMode: isSelectionMode,
                                        onTap: {
                                            if isSelectionMode {
                                                toggleSelection(for: game.id)
                                            }
                                        }
                                    )
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
                
                // Selection Mode Actions
                if isSelectionMode && !selectedGamesForDeletion.isEmpty {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete (\(selectedGamesForDeletion.count))", systemImage: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                            .offset(y: -50)
                        )
                    }
                }
            }
            .navigationTitle("Game History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !filteredGames.isEmpty && !isSelectionMode {
                        Menu {
                            Button(action: {
                                // Export functionality
                            }) {
                                Label("Export Data", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(role: .destructive, action: {
                                showingClearAllConfirmation = true
                            }) {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .alert("Delete Selected Games?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedGames()
            }
        } message: {
            Text("This will permanently delete \(selectedGamesForDeletion.count) game\(selectedGamesForDeletion.count == 1 ? "" : "s"). This action cannot be undone.")
        }
        .alert("Clear All Game History?", isPresented: $showingClearAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                Task {
                    // Delete all games locally via WatchConnectivityManager
                    watchConnectivity.clearAllGames()

                    // Clear all achievements
                    AchievementManager.shared.clearAllAchievements()

                    // Reset profile per user and persist
                    await CompleteUserHealthManager.shared.resetProfileAndPersist()

                    // Attempt to delete from remote services as well
                    let allGames = filteredGames
                    await UnifiedSyncManager.shared.deleteGames(allGames)

                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete all \(filteredGames.count) games. Your achievements and lifetime stats will be reset. This action cannot be undone.")
        }
    }
    
    private func toggleSelection(for gameId: UUID) {
        if selectedGamesForDeletion.contains(gameId) {
            selectedGamesForDeletion.remove(gameId)
        } else {
            selectedGamesForDeletion.insert(gameId)
        }
    }
    
    private func deleteSelectedGames() {
        // Map selected IDs to actual WatchGameRecord instances
        let gamesToDelete: [WatchGameRecord] = watchConnectivity
            .games(for: selectedSport)
            .filter { selectedGamesForDeletion.contains($0.id) }
        
        guard !gamesToDelete.isEmpty else {
            // Clear selection and exit selection mode
            selectedGamesForDeletion.removeAll()
            isSelectionMode = false
            return
        }
        
        // Perform all deletion operations asynchronously and in order
        Task {
            // Delete locally first
            watchConnectivity.deleteGames(gamesToDelete)
            
            // Adjust profile stats per user based on deletions (now async)
            await CompleteUserHealthManager.shared.applyDeletionAdjustments(for: gamesToDelete)
            
            // Delete from remote services
            await UnifiedSyncManager.shared.deleteGames(gamesToDelete)
            
            // Clear selection and exit selection mode on main thread
            await MainActor.run {
                selectedGamesForDeletion.removeAll()
                isSelectionMode = false
            }
        }
    }
}

// History Stats Card - UPDATED
struct HistoryStatsCard: View {
    let games: [WatchGameRecord]
    
    private var totalTime: String {
        let total = games.reduce(0) { $0 + $1.elapsedTime }
        let hours = Int(total) / 3600
        let minutes = Int(total) % 3600 / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    private var winRate: String {
        guard !games.isEmpty else { return "0%" }
        let wins = games.filter { $0.winner == "You" }.count
        return "\(Int((Double(wins) / Double(games.count)) * 100))%"
    }
    
    private var avgGameTime: String {
        guard !games.isEmpty else { return "0m" }
        let avg = games.reduce(0) { $0 + $1.elapsedTime } / Double(games.count)
        let minutes = Int(avg) / 60
        return "\(minutes)m"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Changed from StatItem to HistoryStatItem
            HistoryStatItem(title: "Total Time", value: totalTime, color: .blue)
            Divider()
                .frame(height: 40)
                .background(Color.gray.opacity(0.3))
            HistoryStatItem(title: "Win Rate", value: winRate, color: .green)
            Divider()
                .frame(height: 40)
                .background(Color.gray.opacity(0.3))
            HistoryStatItem(title: "Avg Game", value: avgGameTime, color: .orange)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

// Renamed from StatItem to HistoryStatItem
struct HistoryStatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


// History Game Row
struct HistoryGameRow: View {
    let game: WatchGameRecord
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 24))
            }
            
            HStack(spacing: 16) {
                // Date
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.date, format: .dateTime.day().month())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    Text(game.date, format: .dateTime.hour().minute())
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(width: 60, alignment: .leading)
                
                // Sport emoji
                Text(game.sportEmoji)
                    .font(.system(size: 24))
                
                // Game info
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.gameType)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(game.elapsedTimeDisplay)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Score and result
                VStack(alignment: .trailing, spacing: 2) {
                    Text(game.scoreDisplay)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let winner = game.winner {
                        Text(winner == "You" ? "W" : "L")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(winner == "You" ? .green : .red)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .onTapGesture {
            onTap()
        }
    }
}

// Empty History View
struct EmptyHistoryView: View {
    let selectedSport: SportFilter
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No \(selectedSport == .all ? "" : "\(selectedSport.rawValue) ")Games Yet")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Your game history will appear here")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

