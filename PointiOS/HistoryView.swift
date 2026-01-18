//
//  HistoryView.swift
//  PointiOS
//
//  Enhanced Game History with Filters & Sorting
//

import SwiftUI

struct HistoryView: View {
    @Environment(\.adaptiveColors) var colors
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.dismiss) var dismiss

    // Filters
    @State private var selectedSport: SportFilter
    @State private var selectedResult: ResultFilter = .all
    @State private var selectedDateRange: DateRangeFilter = .allTime
    @State private var selectedGameType: GameTypeFilter = .all
    @State private var sortOrder: SortOrder = .newest
    @State private var showFilters = false

    // Selection & Actions
    @State private var showingDeleteConfirmation = false
    @State private var selectedGamesForDeletion: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingClearAllConfirmation = false
    @State private var clearAchievementsToo = false
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingUpgrade = false
    @State private var selectedGameForDetail: WatchGameRecord? = nil
    @State private var showShareSheet = false
    @State private var exportURL: URL?

    // MARK: - Filter Enums
    enum ResultFilter: String, CaseIterable {
        case all = "All Results"
        case wins = "Wins"
        case losses = "Losses"
    }

    enum DateRangeFilter: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case last3Months = "Last 3 Months"
        case allTime = "All Time"

        var cutoffDate: Date? {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .today:
                return calendar.startOfDay(for: now)
            case .thisWeek:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .thisMonth:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .last3Months:
                return calendar.date(byAdding: .month, value: -3, to: now)
            case .allTime:
                return nil
            }
        }
    }

    enum GameTypeFilter: String, CaseIterable {
        case all = "All Types"
        case singles = "Singles"
        case doubles = "Doubles"
    }

    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case longest = "Longest Duration"
        case shortest = "Shortest Duration"
        case highestScore = "Highest Score"
    }

    init(initialFilter: SportFilter = .all) {
        _selectedSport = State(initialValue: initialFilter)
    }

    // MARK: - Filtered & Sorted Games
    var filteredGames: [WatchGameRecord] {
        var games = watchConnectivity.games(for: selectedSport)

        // Filter by date range
        if let cutoff = selectedDateRange.cutoffDate {
            games = games.filter { $0.date >= cutoff }
        }

        // Filter by result
        switch selectedResult {
        case .all: break
        case .wins:
            games = games.filter { $0.winner == "You" }
        case .losses:
            games = games.filter { $0.winner != "You" }
        }

        // Filter by game type
        switch selectedGameType {
        case .all: break
        case .singles:
            games = games.filter { $0.gameType.lowercased().contains("singles") }
        case .doubles:
            games = games.filter { $0.gameType.lowercased().contains("doubles") }
        }

        // Sort
        switch sortOrder {
        case .newest:
            games.sort { $0.date > $1.date }
        case .oldest:
            games.sort { $0.date < $1.date }
        case .longest:
            games.sort { $0.elapsedTime > $1.elapsedTime }
        case .shortest:
            games.sort { $0.elapsedTime < $1.elapsedTime }
        case .highestScore:
            games.sort { ($0.player1Score + $0.player2Score) > ($1.player1Score + $1.player2Score) }
        }

        return games
    }

    var displayedGames: [WatchGameRecord] {
        if pro.isPro { return filteredGames }
        return Array(filteredGames.prefix(10))
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedSport != .all { count += 1 }
        if selectedResult != .all { count += 1 }
        if selectedDateRange != .allTime { count += 1 }
        if selectedGameType != .all { count += 1 }
        if sortOrder != .newest { count += 1 }
        return count
    }

    var body: some View {
        NavigationView {
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Bar
                    filterBar

                    // Active Filters Summary
                    if activeFilterCount > 0 {
                        activeFiltersSummary
                    }

                    // Games List
                    ScrollView {
                        VStack(spacing: 0) {
                            if !pro.isPro {
                                LockedFeatureCard(
                                    title: "Unlock Full History",
                                    description: "Point Pro lets you browse every game, export data, and sync across devices."
                                ) {
                                    showingUpgrade = true
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }

                            if filteredGames.isEmpty {
                                EmptyHistoryView(selectedSport: selectedSport, hasFilters: activeFilterCount > 0)
                                    .padding(.top, 60)
                            } else {
                                gamesListContent
                            }
                        }
                    }
                }

                // Selection Mode Actions
                if isSelectionMode && !selectedGamesForDeletion.isEmpty {
                    selectionModeOverlay
                }
            }
            .navigationTitle("Game History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
        }
        .sheet(isPresented: $showFilters) {
            filterSheet
        }
        .alert("Delete Selected Games?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedGames()
            }
        } message: {
            Text("This will permanently delete \(selectedGamesForDeletion.count) game\(selectedGamesForDeletion.count == 1 ? "" : "s"). This action cannot be undone.")
        }
        .alert("Clear Game History?", isPresented: $showingClearAllConfirmation) {
            Button("Cancel", role: .cancel) {
                clearAchievementsToo = false
            }
            Button("Clear History Only", role: .destructive) {
                Task {
                    watchConnectivity.clearAllGames()
                    await UnifiedSyncManager.shared.deleteGames(filteredGames)
                    dismiss()
                }
            }
            Button("Clear History + Stats", role: .destructive) {
                Task {
                    watchConnectivity.clearAllGames()
                    AchievementManager.shared.clearAllAchievements()
                    await CompleteUserHealthManager.shared.resetProfileAndPersist()
                    await UnifiedSyncManager.shared.deleteGames(filteredGames)
                    dismiss()
                }
            }
        } message: {
            Text("Choose what to clear:\n\n• History Only: Removes games but keeps your achievements and lifetime stats\n\n• History + Stats: Full reset including achievements")
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

    // MARK: - Filter Bar
    private var filterBar: some View {
        VStack(spacing: 12) {
            // Top row: Filter button and results count
            HStack {
                // Filter Button
                Button(action: { showFilters = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Filters")
                            .font(.system(size: 13, weight: .semibold))
                        if activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SwissColors.green)
                                .cornerRadius(4)
                        }
                    }
                    .foregroundColor(colors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(colors.border, lineWidth: 1)
                    )
                    .cornerRadius(8)
                }

                Spacer()

                // Results count
                Text("\(filteredGames.count) games")
                    .font(SwissTypography.monoLabel(11))
                    .foregroundColor(colors.textSecondary)
            }

            // Sport filter pills row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SportFilter.allCases, id: \.self) { sport in
                        QuickFilterPill(
                            title: sport == .all ? "All" : sport.rawValue,
                            isSelected: selectedSport == sport
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSport = sport
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.background)
    }

    // MARK: - Active Filters Summary
    private var activeFiltersSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if selectedResult != .all {
                    ActiveFilterChip(label: selectedResult.rawValue) {
                        selectedResult = .all
                    }
                }
                if selectedDateRange != .allTime {
                    ActiveFilterChip(label: selectedDateRange.rawValue) {
                        selectedDateRange = .allTime
                    }
                }
                if selectedGameType != .all {
                    ActiveFilterChip(label: selectedGameType.rawValue) {
                        selectedGameType = .all
                    }
                }
                if sortOrder != .newest {
                    ActiveFilterChip(label: sortOrder.rawValue) {
                        sortOrder = .newest
                    }
                }

                if activeFilterCount > 1 {
                    Button(action: clearAllFilters) {
                        Text("Clear All")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SwissColors.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Games List Content
    private var gamesListContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !pro.isPro && filteredGames.count > displayedGames.count {
                Text("Showing \(displayedGames.count) of \(filteredGames.count) games. Upgrade for full access.")
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(colors.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
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

    // MARK: - Selection Mode Overlay
    private var selectionModeOverlay: some View {
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
                    colors: [colors.background.opacity(0), colors.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .offset(y: -50)
            )
        }
    }

    // MARK: - Filter Sheet
    private var filterSheet: some View {
        NavigationView {
            List {
                // Date Range
                Section("Date Range") {
                    ForEach(DateRangeFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedDateRange = filter }) {
                            HStack {
                                Text(filter.rawValue)
                                    .foregroundColor(colors.textPrimary)
                                Spacer()
                                if selectedDateRange == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(SwissColors.green)
                                }
                            }
                        }
                    }
                }

                // Result
                Section("Result") {
                    ForEach(ResultFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedResult = filter }) {
                            HStack {
                                Text(filter.rawValue)
                                    .foregroundColor(colors.textPrimary)
                                Spacer()
                                if selectedResult == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(SwissColors.green)
                                }
                            }
                        }
                    }
                }

                // Game Type
                Section("Game Type") {
                    ForEach(GameTypeFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedGameType = filter }) {
                            HStack {
                                Text(filter.rawValue)
                                    .foregroundColor(colors.textPrimary)
                                Spacer()
                                if selectedGameType == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(SwissColors.green)
                                }
                            }
                        }
                    }
                }

                // Sort Order
                Section("Sort By") {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(action: { sortOrder = order }) {
                            HStack {
                                Text(order.rawValue)
                                    .foregroundColor(colors.textPrimary)
                                Spacer()
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(SwissColors.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        clearAllFilters()
                    }
                    .foregroundColor(SwissColors.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFilters = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    // MARK: - Helper Functions
    private func clearAllFilters() {
        selectedSport = .all
        selectedResult = .all
        selectedDateRange = .allTime
        selectedGameType = .all
        sortOrder = .newest
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
        let gamesToDelete: [WatchGameRecord] = watchConnectivity
            .games(for: selectedSport)
            .filter { selectedGamesForDeletion.contains($0.id) }

        guard !gamesToDelete.isEmpty else {
            selectedGamesForDeletion.removeAll()
            isSelectionMode = false
            return
        }

        Task {
            watchConnectivity.deleteGames(gamesToDelete)
            CompleteUserHealthManager.shared.applyDeletionAdjustments(for: gamesToDelete)
            await UnifiedSyncManager.shared.deleteGames(gamesToDelete)

            await MainActor.run {
                selectedGamesForDeletion.removeAll()
                isSelectionMode = false
            }
        }
    }
}

// MARK: - Quick Filter Pill
private struct QuickFilterPill: View {
    @Environment(\.adaptiveColors) var colors
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? colors.textPrimary : colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : colors.border, lineWidth: 1)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active Filter Chip
private struct ActiveFilterChip: View {
    @Environment(\.adaptiveColors) var colors
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundColor(SwissColors.green)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SwissColors.green.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(SwissColors.green.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Empty History View
struct EmptyHistoryView: View {
    @Environment(\.adaptiveColors) var colors
    let selectedSport: SportFilter
    var hasFilters: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasFilters ? "line.3.horizontal.decrease.circle" : "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(colors.textSecondary.opacity(0.6))

            Text(hasFilters ? "No Matching Games" : "No \(selectedSport == .all ? "" : "\(selectedSport.rawValue) ")Games Yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colors.textPrimary)

            Text(hasFilters ? "Try adjusting your filters" : "Your game history will appear here")
                .font(SwissTypography.monoLabel(11))
                .foregroundColor(colors.textSecondary)
        }
    }
}
