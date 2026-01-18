//
//  SwissDashboardView.swift
//  PointiOS
//
//  Swiss Minimalist Dashboard - Main Activity View
//

import SwiftUI

struct SwissDashboardView: View {
    @Environment(\.adaptiveColors) var colors
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @StateObject private var locationDataManager = LocationDataManager.shared
    @State private var showingSessionShare = false
    @State private var showingLocationPicker = false
    @State private var selectedGameForDetail: WatchGameRecord? = nil
    @State private var showingDatePicker = false
    @ObservedObject private var pro = ProEntitlements.shared
    @State private var showingProSheet = false
    @State private var showingHistoryView = false
    @State private var selectedDate: Date = Date()
    @State private var headerVisible = false
    @State private var sessionVisible = false
    @State private var statsVisible = false
    @State private var activityVisible = false

    // Check if viewing today or a different date
    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    // Games for the selected date
    private var gamesForSelectedDate: [WatchGameRecord] {
        watchConnectivity.receivedGames.filter { game in
            Calendar.current.isDate(game.date, inSameDayAs: selectedDate)
        }
    }

    var selectedDateSession: SessionSummary {
        let games = gamesForSelectedDate
        let wins = games.filter { $0.winner == "You" }.count
        let totalTime = games.reduce(0) { $0 + $1.elapsedTime }
        let totalCalories = games.compactMap { $0.healthData?.totalCalories }.reduce(0, +)
        let heartRates = games.compactMap { $0.healthData?.averageHeartRate }
        let avgHeartRate = heartRates.isEmpty ? 0 : heartRates.reduce(0, +) / Double(heartRates.count)

        // Determine most common sport from today's games
        let sportCounts = Dictionary(grouping: games, by: { $0.sportType })
        let mostCommonSport = sportCounts.max(by: { $0.value.count < $1.value.count })?.key ?? "Pickleball"

        return SessionSummary(
            date: selectedDate,
            location: locationDataManager.currentLocation,
            gamesPlayed: games.count,
            gamesWon: wins,
            totalTime: totalTime,
            calories: totalCalories,
            avgHeartRate: avgHeartRate,
            sport: mostCommonSport
        )
    }

    // Lifetime stats
    private var lifetimeRecord: (wins: Int, losses: Int) {
        let wins = watchConnectivity.receivedGames.filter { $0.winner == "You" }.count
        let losses = watchConnectivity.receivedGames.count - wins
        return (wins, losses)
    }

    private var totalHoursPlayed: Double {
        watchConnectivity.receivedGames.reduce(0) { $0 + $1.elapsedTime } / 3600
    }

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : -20)

                    // Session Card for selected date
                    if !gamesForSelectedDate.isEmpty {
                        selectedDateSessionSection
                            .opacity(sessionVisible ? 1 : 0)
                            .offset(y: sessionVisible ? 0 : 20)
                    }

                    // Stats Grid Row
                    statsGridSection
                        .opacity(statsVisible ? 1 : 0)
                        .offset(y: statsVisible ? 0 : 20)

                    // Recent Activity Section
                    recentActivitySection
                        .opacity(activityVisible ? 1 : 0)
                        .offset(y: activityVisible ? 0 : 20)

                    // Bottom padding for FAB
                    Color.clear.frame(height: 100)
                }
            }

        }
        .onAppear {
            animateIn()
            // Trigger GPS location detection
            locationDataManager.detectCurrentLocation()
        }
        .sheet(isPresented: $showingSessionShare) {
            SessionShareView(sessionData: selectedDateSession)
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView()
                .environmentObject(locationDataManager)
        }
        .sheet(item: $selectedGameForDetail) { game in
            SwissGameDetailView(game: game)
        }
        .sheet(isPresented: $showingProSheet) {
            UpgradeView()
        }
        .sheet(isPresented: $showingDatePicker) {
            SwissDatePickerModal(
                selectedDate: $selectedDate,
                datesWithGames: Set(watchConnectivity.receivedGames.map { Calendar.current.startOfDay(for: $0.date) }),
                gamesByDate: Dictionary(grouping: watchConnectivity.receivedGames) { Calendar.current.startOfDay(for: $0.date) }
            )
        }
        .sheet(isPresented: $showingHistoryView) {
            HistoryView()
                .environmentObject(watchConnectivity)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with logo and sync
            HStack {
                PointWordmark(size: 26)

                Spacer()

                // Watch connection status
                HStack(spacing: 8) {
                    Circle()
                        .fill(watchConnectivity.isWatchConnected ? SwissColors.green : colors.textMuted)
                        .frame(width: 8, height: 8)
                    Text(watchConnectivity.isWatchConnected ? "Watch Connected" : "Watch Offline")
                        .font(SwissTypography.monoLabel(11))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()
                    .frame(width: 16)

                Button(action: {
                    WatchConnectivityManager.shared.manualCheckForPendingData()
                    Task {
                        await WatchConnectivityManager.shared.refreshFromCloud()
                    }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(colors.textPrimary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)

            // Date display
            HStack(alignment: .bottom) {
                Button(action: { showingDatePicker = true }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)).uppercased())
                            .font(.system(size: 40, weight: .bold))
                            .tracking(-2)
                            .foregroundColor(colors.textPrimary)

                        HStack(spacing: 8) {
                            Text(selectedDate.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                                .font(.system(size: 24, weight: .bold))
                                .tracking(-1)
                                .foregroundColor(colors.textSecondary)

                            if !isViewingToday {
                                Text("•")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(colors.textTertiary)

                                Text(selectedDate.formatted(.dateTime.year()))
                                    .font(.system(size: 24, weight: .bold))
                                    .tracking(-1)
                                    .foregroundColor(colors.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Back to Today button (only shows when viewing past date)
                if !isViewingToday {
                    Button(action: {
                        withAnimation(SwissAnimation.gentle) {
                            selectedDate = Date()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 12, weight: .semibold))
                            Text("TODAY")
                                .font(SwissTypography.monoLabel(11))
                                .tracking(1)
                        }
                        .foregroundColor(SwissColors.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle()
                                .stroke(SwissColors.green, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .accessibilityLabel("\(isViewingToday ? "Today" : selectedDate.formatted(.dateTime.weekday(.wide))), \(selectedDate.formatted(.dateTime.month(.wide).day()))")
            .accessibilityHint("Double tap to select a different date")

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
        }
    }

    // MARK: - Selected Date Session Section
    private var selectedDateSessionSection: some View {
        let session = selectedDateSession
        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(isViewingToday ? "Today's Session" : "Session")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(colors.textSecondary)

                Spacer()

                Button(action: {
                    HapticManager.shared.impact(.light)
                    showingSessionShare = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Share")
                            .font(SwissTypography.monoLabel(11))
                            .textCase(.uppercase)
                            .tracking(1)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(SwissColors.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(SwissColors.green)
                }
                .pressEffect(scale: 0.95)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)

            // Main Stats Row
            HStack(spacing: 24) {
                // Games Won
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(session.gamesWon)")
                            .font(.system(size: 56, weight: .bold))
                            .tracking(-2)
                            .foregroundColor(colors.textPrimary)
                        Text("/\(session.gamesPlayed)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(colors.textTertiary)
                    }
                    Text("Games Won")
                        .font(SwissTypography.monoLabel(10))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                // Play Time
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatTime(session.totalTime))
                        .font(.system(size: 36, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(colors.textPrimary)
                    Text("Play Time")
                        .font(SwissTypography.monoLabel(10))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundColor(colors.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Secondary Stats
            HStack(spacing: 16) {
                // Calories
                HStack(spacing: 12) {
                    Image(systemName: "flame")
                        .font(.system(size: 20))
                        .foregroundColor(colors.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.calories > 0 ? "\(Int(session.calories))" : "--")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colors.textPrimary)
                        Text("Cal")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(colors.textSecondary)
                    }
                }

                Spacer()

                // Heart Rate
                HStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 20))
                        .foregroundColor(colors.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.avgHeartRate > 0 ? "\(Int(session.avgHeartRate))" : "--")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colors.textPrimary)
                        Text("Avg BPM")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(colors.textSecondary)
                    }
                }

                Spacer()

                // Location with GPS suggestion
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showingLocationPicker = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin")
                                .font(.system(size: 20))
                                .foregroundColor(colors.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(locationDataManager.currentLocation)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(colors.textPrimary)
                                    .lineLimit(1)
                                Text("Court")
                                    .font(SwissTypography.monoLabel(9))
                                    .foregroundColor(colors.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // GPS detected location suggestion
                    if let detected = locationDataManager.detectedLocation,
                       detected.lowercased() != locationDataManager.currentLocation.lowercased() {
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            withAnimation(SwissAnimation.gentle) {
                                locationDataManager.useDetectedLocation()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text("Use: \(detected)")
                                    .font(SwissTypography.monoLabel(9))
                                    .lineLimit(1)
                            }
                            .foregroundColor(SwissColors.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SwissColors.green.opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .overlay(
                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(height: 1),
                alignment: .top
            )

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
        }
    }

    // MARK: - Stats Grid Section
    private var statsGridSection: some View {
        HStack(spacing: 0) {
            // Win Record
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(SwissColors.green)
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)

                Text("\(lifetimeRecord.wins)-\(lifetimeRecord.losses)")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-2)
                    .foregroundColor(colors.textPrimary)
                    .padding(.bottom, 6)

                Text("Win Record")
                    .font(SwissTypography.monoLabel(10))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Win record: \(lifetimeRecord.wins) wins, \(lifetimeRecord.losses) losses")
            .overlay(
                Rectangle()
                    .fill(colors.borderSubtle)
                    .frame(width: 1),
                alignment: .trailing
            )

            // Hours Active
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 24))
                    .foregroundColor(SwissColors.green)
                    .padding(.bottom, 12)
                    .accessibilityHidden(true)

                Text(String(format: "%.1f", totalHoursPlayed))
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-2)
                    .foregroundColor(colors.textPrimary)
                    .padding(.bottom, 6)

                Text("Hours Active")
                    .font(SwissTypography.monoLabel(10))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Hours active: \(String(format: "%.1f", totalHoursPlayed)) hours")
        }
        .overlay(
            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        // When viewing a specific date, show games from that date
        // Otherwise show recent 10 games across all dates
        let gamesToShow: [WatchGameRecord] = isViewingToday
            ? Array(watchConnectivity.receivedGames.prefix(10))
            : gamesForSelectedDate

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            SwissSectionHeader(
                title: isViewingToday ? "Recent Activity" : "Games on \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))",
                action: {
                    HapticManager.shared.impact(.light)
                    showingHistoryView = true
                }
            )
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)

            // Games list
            if gamesToShow.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(gamesToShow.enumerated()), id: \.element.id) { index, game in
                        SwissActivityRow(game: game, onTap: {
                            HapticManager.shared.impact(.light)
                            guard pro.isPro else {
                                showingProSheet = true
                                return
                            }
                            if let events = game.events, !events.isEmpty {
                                selectedGameForDetail = game
                            }
                        })
                        .padding(.horizontal, 24)

                        if index < gamesToShow.count - 1 {
                            Rectangle()
                                .fill(colors.borderSubtle)
                                .frame(height: 1)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if isViewingToday {
                // Multi-sport icon stack for today
                HStack(spacing: 16) {
                    Text("🎾")
                        .font(.system(size: 36))
                        .opacity(0.6)
                    Text("🏓")
                        .font(.system(size: 44))
                    Text("🥒")
                        .font(.system(size: 36))
                        .opacity(0.6)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tennis, Padel, and Pickleball")

                Text("No Games Yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(colors.textPrimary)

                Text("Start playing on your Apple Watch\nto track your games")
                    .font(SwissTypography.monoLabel(11))
                    .multilineTextAlignment(.center)
                    .foregroundColor(colors.textSecondary)
                    .lineSpacing(4)

            } else {
                // Empty state for a specific past date
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(colors.textMuted)

                Text("No Games on This Day")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(colors.textPrimary)

                Text("Try selecting a different date\nor tap the calendar to browse")
                    .font(SwissTypography.monoLabel(11))
                    .multilineTextAlignment(.center)
                    .foregroundColor(colors.textSecondary)
                    .lineSpacing(4)

                Button(action: {
                    withAnimation(SwissAnimation.gentle) {
                        selectedDate = Date()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Back to Today")
                    }
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .fontWeight(.bold)
                }
                .buttonStyle(SwissPrimaryButtonStyle())
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        TimeFormatter.format(interval)
    }

    private func animateIn() {
        withAnimation(SwissAnimation.gentle) {
            headerVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.1)) {
            sessionVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.2)) {
            statsVisible = true
        }
        withAnimation(SwissAnimation.gentle.delay(0.3)) {
            activityVisible = true
        }
    }
}

// MARK: - Date Picker Modal
struct SwissDatePickerModal: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.adaptiveColors) var colors
    @Binding var selectedDate: Date
    let datesWithGames: Set<Date>
    var gamesByDate: [Date: [WatchGameRecord]] = [:]

    @State private var displayedMonth: Date = Date()
    @State private var tempDate: Date = Date()

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    // Sport colors
    private let sportColors: [String: Color] = [
        "Tennis": Color(red: 0.85, green: 0.65, blue: 0.13),    // Gold/Yellow
        "Pickleball": SwissColors.green,                         // Green
        "Padel": Color(red: 0.20, green: 0.60, blue: 0.86)      // Blue
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Date")
                    .font(SwissTypography.monoLabel(12))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .fontWeight(.bold)
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(colors.textPrimary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Month Navigation
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colors.textPrimary)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text(monthYearString(from: displayedMonth))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colors.textPrimary)

                Spacer()

                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canGoForward ? colors.textPrimary : colors.textMuted)
                        .frame(width: 44, height: 44)
                }
                .disabled(!canGoForward)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Legend
            HStack(spacing: 16) {
                ForEach(["Tennis", "Pickleball", "Padel"], id: \.self) { sport in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(sportColors[sport] ?? colors.textMuted)
                            .frame(width: 6, height: 6)
                        Text(sport)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(colors.textSecondary)
                    }
                }
            }
            .padding(.bottom, 16)

            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Calendar Grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    if let date = day {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: tempDate),
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date(),
                            sports: sportsOnDate(date),
                            sportColors: sportColors
                        ) {
                            if date <= Date() {
                                HapticManager.shared.selection()
                                tempDate = date
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 52)
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Confirm button
            Button(action: {
                HapticManager.shared.impact(.medium)
                selectedDate = tempDate
                dismiss()
            }) {
                Text("SELECT DATE")
                    .font(SwissTypography.monoLabel(13))
                    .tracking(1.5)
                    .fontWeight(.bold)
                    .foregroundColor(SwissColors.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(SwissColors.green)
            }
            .padding(24)
        }
        .background(colors.background)
        .onAppear {
            tempDate = selectedDate
            displayedMonth = selectedDate
        }
    }

    // MARK: - Helper Functions

    private var canGoForward: Bool {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        return nextMonth <= Date()
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = newMonth
            }
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func daysInMonth() -> [Date?] {
        var days: [Date?] = []

        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return days
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)

        // Add empty cells for days before the first of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Add actual days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func sportsOnDate(_ date: Date) -> Set<String> {
        let startOfDay = calendar.startOfDay(for: date)
        guard let games = gamesByDate[startOfDay] else { return [] }
        return Set(games.map { $0.sportType })
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    @Environment(\.adaptiveColors) var colors
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let sports: Set<String>
    let sportColors: [String: Color]
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(dayTextColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Group {
                            if isSelected {
                                Circle()
                                    .fill(colors.primary)
                            } else if isToday {
                                Circle()
                                    .stroke(SwissColors.green, lineWidth: 2)
                            }
                        }
                    )

                // Sport dots
                HStack(spacing: 3) {
                    if sports.contains("Tennis") {
                        Circle()
                            .fill(sportColors["Tennis"] ?? colors.textMuted)
                            .frame(width: 5, height: 5)
                    }
                    if sports.contains("Pickleball") {
                        Circle()
                            .fill(sportColors["Pickleball"] ?? colors.textMuted)
                            .frame(width: 5, height: 5)
                    }
                    if sports.contains("Padel") {
                        Circle()
                            .fill(sportColors["Padel"] ?? colors.textMuted)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(height: 52)
        }
        .disabled(isFuture)
    }

    private var dayTextColor: Color {
        if isSelected {
            return colors.primaryInverted
        } else if isFuture {
            return colors.textMuted
        } else if isToday {
            return SwissColors.green
        } else {
            return colors.textPrimary
        }
    }
}

#Preview {
    SwissDashboardView()
        .environmentObject(WatchConnectivityManager.shared)
}
