//
//  SportFilterTabs.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/20/25.
//

import SwiftUI

struct SportFilterTabs: View {
    @Binding var selectedSport: SportFilter
    
    var body: some View {
        HStack(spacing: 8) {
            SportFilterTab(title: "All", isSelected: selectedSport == .all, color: .gray) {
                selectedSport = .all
            }
            
            SportFilterTab(title: "🏓 PB", isSelected: selectedSport == .pickleball, color: .green) {
                selectedSport = .pickleball
            }
            
            SportFilterTab(title: "🎾 Ten", isSelected: selectedSport == .tennis, color: .blue) {
                selectedSport = .tennis
            }
            
            SportFilterTab(title: "🎾 Pad", isSelected: selectedSport == .padel, color: .purple) {
                selectedSport = .padel
            }
        }
    }
}

struct SportFilterTab: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? color : Color.gray.opacity(0.3))
                )
        }
    }
}

struct ProfileCard: View {
    @Binding var isEditing: Bool
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    let selectedSport: SportFilter
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Header
            HStack {
                // Avatar
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text("👤")
                            .font(.system(size: 30))
                    )
                
                // Name and Rating
                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Display Name", text: $appData.displayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        // Sport-specific rating editor
                        HStack {
                            Text(getRatingLabel())
                                .foregroundColor(getRatingColor())
                                .fontWeight(.semibold)
                            
                            TextField("3.8", text: getRatingBinding())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                        }
                    } else {
                        Text(appData.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if selectedSport != .all {
                            Text("\(getRatingLabel()) \(getRatingValue())")
                                .foregroundColor(getRatingColor())
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                Spacer()
                
                // Edit Button
                Button(action: { isEditing.toggle() }) {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.gray.opacity(0.6)))
                }
            }
            
            // Stats Grid
            HStack(spacing: 0) {
                StatItem(
                    title: "L10",
                    value: getL10Stats(),
                    color: .green
                )
                Spacer()
                StatItem(
                    title: "Win %",
                    value: getWinPercentage(),
                    color: .blue
                )
                Spacer()
                StatItem(
                    title: "Games",
                    value: getGamesCount(),
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isEditing ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
    
    // Helper methods
    private func getRatingLabel() -> String {
        switch selectedSport {
        case .pickleball: return "DUPR:"
        case .tennis: return "UTR:"
        case .padel: return "Playtomic:"
        case .all: return ""
        }
    }
    
    private func getRatingColor() -> Color {
        switch selectedSport {
        case .pickleball: return .green
        case .tennis: return .blue
        case .padel: return .purple
        case .all: return .gray
        }
    }
    
    private func getRatingValue() -> String {
        switch selectedSport {
        case .pickleball: return appData.duprScore
        case .tennis: return appData.utrScore
        case .padel: return appData.playtomicScore
        case .all: return ""
        }
    }
    
    private func getRatingBinding() -> Binding<String> {
        switch selectedSport {
        case .pickleball: return $appData.duprScore
        case .tennis: return $appData.utrScore
        case .padel: return $appData.playtomicScore
        case .all: return .constant("")
        }
    }
    
    private func getL10Stats() -> String {
        let games = watchConnectivity.games(for: selectedSport)
        let last10 = Array(games.prefix(10))
        let wins = last10.filter { $0.winner == "You" }.count
        let losses = last10.count - wins
        return "\(wins)-\(losses)"
    }
    
    private func getWinPercentage() -> String {
        let games = watchConnectivity.games(for: selectedSport)
        guard !games.isEmpty else { return "0%" }
        let wins = games.filter { $0.winner == "You" }.count
        let percentage = (Double(wins) / Double(games.count)) * 100
        return "\(Int(percentage))%"
    }
    
    private func getGamesCount() -> String {
        let games = watchConnectivity.games(for: selectedSport)
        return "\(games.count)"
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(value)
                .foregroundColor(.gray)
        }
    }
}

struct PlayStyleCard: View {
    @Binding var isEditing: Bool
    @EnvironmentObject var appData: AppData
    let selectedSport: SportFilter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedSport == .all ? "Sport Distribution" : "Your Play Style")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                if selectedSport != .all {
                    if isEditing {
                        Button("Done") {
                            withAnimation {
                                isEditing = false
                            }
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    } else {
                        Button(action: { isEditing = true }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                )
                        }
                    }
                }
            }
            
            if selectedSport == .all {
                // Sport distribution graph
                SportDistributionView()
            } else if isEditing {
                VStack(spacing: 8) {
                    switch selectedSport {
                    case .pickleball:
                        ForEach(PickleballPlayStyle.allCases, id: \.self) { style in
                            PlayStyleOption(
                                emoji: style.emoji,
                                name: style.name,
                                description: style.description,
                                isSelected: appData.pickleballPlayStyle == style
                            ) {
                                appData.pickleballPlayStyle = style
                            }
                        }
                    case .tennis:
                        ForEach(TennisPlayStyle.allCases, id: \.self) { style in
                            PlayStyleOption(
                                emoji: style.emoji,
                                name: style.name,
                                description: style.description,
                                isSelected: appData.tennisPlayStyle == style
                            ) {
                                appData.tennisPlayStyle = style
                            }
                        }
                    case .padel:
                        ForEach(PadelPlayStyle.allCases, id: \.self) { style in
                            PlayStyleOption(
                                emoji: style.emoji,
                                name: style.name,
                                description: style.description,
                                isSelected: appData.padelPlayStyle == style
                            ) {
                                appData.padelPlayStyle = style
                            }
                        }
                    case .all:
                        EmptyView()
                    }
                }
            } else {
                // Display current play style
                let (emoji, name, description) = getCurrentPlayStyle()

                Button(action: { isEditing = true }) {
                    HStack(spacing: 12) {
                        Text(emoji)
                            .font(.system(size: 32))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "pencil")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5).opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private func getCurrentPlayStyle() -> (emoji: String, name: String, description: String) {
        switch selectedSport {
        case .pickleball:
            return (appData.pickleballPlayStyle.emoji,
                   appData.pickleballPlayStyle.name,
                   appData.pickleballPlayStyle.description)
        case .tennis:
            return (appData.tennisPlayStyle.emoji,
                   appData.tennisPlayStyle.name,
                   appData.tennisPlayStyle.description)
        case .padel:
            return (appData.padelPlayStyle.emoji,
                   appData.padelPlayStyle.name,
                   appData.padelPlayStyle.description)
        case .all:
            return ("🏃", "All Sports", "Select a sport to see your play style")
        }
    }
}

// Sport Distribution View for "All" tab - with Donut Chart
struct SportDistributionView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var appData: AppData

    private var donutData: [DonutChartData] {
        let games = watchConnectivity.receivedGames
        guard !games.isEmpty else { return [] }

        let pbCount = games.filter { $0.sportType == "Pickleball" }.count
        let tennisCount = games.filter { $0.sportType == "Tennis" }.count
        let padelCount = games.filter { $0.sportType == "Padel" }.count

        let colorScheme = appData.chartColorScheme
        var data: [DonutChartData] = []

        if pbCount > 0 {
            data.append(DonutChartData(label: "Pickleball", value: Double(pbCount), color: colorScheme.pickleballColor, icon: "🥒"))
        }
        if tennisCount > 0 {
            data.append(DonutChartData(label: "Tennis", value: Double(tennisCount), color: colorScheme.tennisColor, icon: "🎾"))
        }
        if padelCount > 0 {
            data.append(DonutChartData(label: "Padel", value: Double(padelCount), color: colorScheme.padelColor, icon: "🏓"))
        }

        return data
    }

    private var totalGames: Int {
        watchConnectivity.receivedGames.count
    }

    var body: some View {
        VStack(spacing: 16) {
            if donutData.isEmpty {
                Text("No games played yet")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                DonutChart(
                    data: donutData,
                    centerText: "\(totalGames)",
                    size: 160,
                    lineWidth: 32
                )
            }
        }
    }
}

struct PlayStyleOption: View {
    let emoji: String
    let name: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray5).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AchievementsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack(spacing: 20) {
                ForEach(0..<4) { index in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(index < 3 ? Color.yellow : Color.gray.opacity(0.6))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(index < 3 ? "🏆" : "🔒")
                                    .font(.title3)
                            )
                        
                        Text(index < 3 ? "\(index + 1)" : "?")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
        )
    }
}

struct GameHistoryCard: View {
    let selectedSport: SportFilter
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let games = watchConnectivity.games(for: selectedSport).prefix(5)
            
            HStack {
                Text(selectedSport == .all ? "Recent Games" : "\(selectedSport.rawValue.capitalized) Games")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(games.count) games")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                ForEach(Array(games), id: \.id) { game in
                    GameHistoryRow(game: game)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
        )
    }
}

struct GameHistoryRow: View {
    let game: WatchGameRecord
    
    var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: game.date, relativeTo: Date())
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(game.sportType) \(game.gameType)")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(game.scoreDisplay)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let winner = game.winner {
                    Text(winner == "You" ? "Won" : "Lost")
                        .font(.caption)
                        .foregroundColor(winner == "You" ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
        )
    }
}
