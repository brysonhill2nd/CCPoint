//
//  HistoryView.swift
//  PointiOS
//
//  Created by Bryson Hill II on 8/6/25.
//

// HistoryView.swift - Corrected
import SwiftUI

struct HistoryView: View {
    @Environment(\.adaptiveColors) var colors
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedSport: SportFilter
    @State private var showingDeleteConfirmation = false
    @State private var selectedGamesForDeletion: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingClearAllConfirmation = false
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingUpgrade = false
    @State private var selectedGameForDetail: WatchGameRecord? = nil
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    init(initialFilter: SportFilter = .all) {
        _selectedSport = State(initialValue: initialFilter)
    }
    
    var filteredGames: [WatchGameRecord] {
        watchConnectivity.games(for: selectedSport)
    }
    
    var displayedGames: [WatchGameRecord] {
        if pro.isPro { return filteredGames }
        return Array(filteredGames.prefix(10))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        SwissSectionHeader(title: "Game History")
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                        
                        if !pro.isPro {
                            LockedFeatureCard(
                                title: "Unlock Full History",
                                description: "Point Pro lets you browse every game, export data, and sync across devices."
                            ) {
                                showingUpgrade = true
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        }
                        
                        // Games List
                        if filteredGames.isEmpty {
                            EmptyHistoryView(selectedSport: selectedSport)
                                .padding(.top, 60)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                if !pro.isPro && filteredGames.count > displayedGames.count {
                                    Text("Showing your latest 10 games. Upgrade to Point Pro for unlimited history and exports.")
                                        .font(SwissTypography.monoLabel(10))
                                        .foregroundColor(colors.textSecondary)
                                        .padding(.horizontal, 24)
                                }

                                LazyVStack(spacing: 0) {
                                    ForEach(displayedGames) { game in
                                        SwissActivityRow(game: game) {
                                            if isSelectionMode {
                                                toggleSelection(for: game.id)
                                            } else if pro.isPro {
                                                selectedGameForDetail = game
                                            } else {
                                                showingUpgrade = true
                                            }
                                        }
                                        .pressEffect()
                                        .padding(.horizontal, 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(colors.surface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isSelectionMode && selectedGamesForDeletion.contains(game.id)
                                                        ? SwissColors.green
                                                        : colors.borderSubtle,
                                                    lineWidth: isSelectionMode && selectedGamesForDeletion.contains(game.id) ? 2 : 1
                                                )
                                        )

                                        if game.id != displayedGames.last?.id {
                                            Rectangle()
                                                .fill(colors.borderSubtle)
                                                .frame(height: 1)
                                                .padding(.horizontal, 24)
                                        }
                                    }
                                }
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
                    if !filteredGames.isEmpty {
                        Button(isSelectionMode ? "Cancel" : "Select") {
                            withAnimation {
                                isSelectionMode.toggle()
                                if !isSelectionMode {
                                    selectedGamesForDeletion.removeAll()
                                }
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !filteredGames.isEmpty && !isSelectionMode {
                        Menu {
                            Button(action: {
                                if pro.isPro {
                                    Task { await exportCSV() }
                                } else {
                                    showingUpgrade = true
                                }
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
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
        }
        .sheet(item: $selectedGameForDetail) { game in
            SwissGameDetailView(game: game)
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            if let url = exportURL {
                try? FileManager.default.removeItem(at: url)
                exportURL = nil
            }
        }) {
            if let url = exportURL {
                ExportShareSheet(activityItems: [url])
            }
        }
    }
    
    private func toggleSelection(for gameId: UUID) {
        if selectedGamesForDeletion.contains(gameId) {
            selectedGamesForDeletion.remove(gameId)
        } else {
            selectedGamesForDeletion.insert(gameId)
        }
    }

    private func exportCSV() async {
        let games = filteredGames
        guard !games.isEmpty else { return }

        let header = "Date,Sport,Type,Score,Winner,Duration (s),Location\n"
        let rows = games.map { game -> String in
            let date = ISO8601DateFormatter().string(from: game.date)
            let sport = game.sportType
            let type = game.gameType
            let score = "\"\(game.player1Score)-\(game.player2Score)\""
            let winner = game.winner ?? "Unknown"
            let duration = Int(game.elapsedTime)
            let location = game.location ?? "N/A"
            return "\(date),\(sport),\(type),\(score),\(winner),\(duration),\"\(location)\""
        }.joined(separator: "\n")

        let csvString = header + rows
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PointGames.csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            await MainActor.run {
                exportURL = tempURL
                showShareSheet = true
            }
        } catch {
            print("CSV export failed: \(error.localizedDescription)")
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

// Empty History View
struct EmptyHistoryView: View {
    @Environment(\.adaptiveColors) var colors
    let selectedSport: SportFilter
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(colors.textSecondary.opacity(0.6))
            
            Text("No \(selectedSport == .all ? "" : "\(selectedSport.rawValue) ")Games Yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colors.textPrimary)
            
            Text("Your game history will appear here")
                .font(SwissTypography.monoLabel(11))
                .foregroundColor(colors.textSecondary)
        }
    }
}
