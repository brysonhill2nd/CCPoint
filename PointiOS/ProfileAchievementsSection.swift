//
//  ProfileAchievementsSection.swift
//  PointiOS
//
//  Updated Profile Achievements Section matching the new design
//

import SwiftUI

struct ProfileAchievementsSection: View {
    @StateObject private var achievementManager = AchievementManager.shared
    @State private var showingAllAchievements = false
    
    var topAchievements: [(AchievementDefinition, AchievementProgress)] {
        achievementManager.getTopAchievements(count: 5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with See All button
            HStack {
                Text("Achievements")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {
                    showingAllAchievements = true
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.blue)
            }
            
            // Points display
            Text("\(achievementManager.totalPoints) points")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.yellow)
            
            // Achievement circles
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    if index < topAchievements.count {
                        let (definition, progress) = topAchievements[index]
                        AchievementCircle(
                            icon: definition.icon,
                            tier: progress.highestTierAchieved ?? .regular
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        LockedAchievementCircle()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.11))
        )
        .sheet(isPresented: $showingAllAchievements) {
            AchievementsView()
        }
    }
}

struct AchievementCircle: View {
    let icon: String
    let tier: AchievementTier
    
    var backgroundColor: Color {
        switch tier {
        case .platinum:
            return Color(hex: "#E5E4E2")
        case .gold:
            return Color(hex: "#FFD700")
        case .silver:
            return Color(hex: "#C0C0C0")
        case .bronze:
            return Color(hex: "#CD7F32")
        case .regular:
            return Color.gray
        }
    }
    
    var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: 50, height: 50)
            .overlay(
                Text(icon)
                    .font(.system(size: 24))
            )
    }
}

struct LockedAchievementCircle: View {
    var body: some View {
        Circle()
            .fill(Color(white: 0.23))
            .frame(width: 50, height: 50)
            .overlay(
                Text("🔒")
                    .font(.system(size: 24))
            )
    }
}
