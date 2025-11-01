// GameView.swift
import SwiftUI

struct GameView: View {
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @StateObject private var locationDataManager = LocationDataManager.shared
    @State private var showingSessionShare = false
    @State private var showingLocationPicker = false
    @State private var selectedGameForDetail: WatchGameRecord? = nil

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
            ScrollView {
                VStack(spacing: 30) {
                    // Header Section
                    VStack(spacing: 8) {
                        Text("Today")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(Date(), style: .date)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Today's Session Card
                    if !watchConnectivity.todaysGames.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            // Card Header
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Today's Session")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)

                                    Button(action: { showingLocationPicker = true }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            Text(locationDataManager.currentLocation)
                                                .font(.system(size: 16))
                                                .foregroundColor(.gray)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Spacer()
                                
                                Button(action: { showingSessionShare = true }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(20)
                            
                            // Stats Section
                            VStack(spacing: 16) {
                                // Games Won
                                HStack {
                                    HStack(spacing: 12) {
                                        Text("🏆")
                                            .font(.system(size: 24))
                                        Text("Games Won")
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(todaysSession.gamesWon) of \(todaysSession.gamesPlayed)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                // Time Played
                                HStack {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.blue)
                                        Text("Time Played")
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatTime(todaysSession.totalTime))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
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
                                                .foregroundColor(.white)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.gray)
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
                                                .foregroundColor(.white)
                                        } else {
                                            Text("--")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            .padding(20)
                            .padding(.top, -5)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(white: 0.08))
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Today's Games Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today's Games")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        // Games List
                        if watchConnectivity.todaysGames.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "figure.pickleball")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No Games Today")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("Start playing on your Apple Watch\nto track today's games")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(watchConnectivity.todaysGames) { game in
                                    GameRow(game: game) {
                                        if let events = game.events, !events.isEmpty {
                                            selectedGameForDetail = game
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                        .frame(height: 100)
                }
            }
            .background(Color.black)
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
                        .foregroundColor(.white)
                    
                    Text(timeString)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Score and result
                VStack(alignment: .trailing, spacing: 2) {
                    Text(game.scoreDisplay)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let winner = game.winner {
                        Text(winner == "You" ? "Won" : "Lost")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(winner == "You" ? .green : .red)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
