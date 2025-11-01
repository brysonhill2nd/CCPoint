//
//  AchievementsView.swift
//  PointiOS
//
//  Full Achievements Display View - Matching HTML Mockup Design
//

import SwiftUI

struct AchievementsView: View {
    @StateObject private var achievementManager = AchievementManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SportTab = .all
    
    enum SportTab: String, CaseIterable {
        case all = "All"
        case pb = "PB"
        case tennis = "Tennis"
        case padel = "Padel"
    }
    
    var unlockedCount: Int {
        achievementManager.userProgress.values.filter { $0.highestTierAchieved != nil }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Navigation Bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Achievements")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 0) {
                            Text("\(unlockedCount)")
                                .foregroundColor(.yellow)
                                .fontWeight(.semibold)
                            Text(" unlocked • ")
                                .foregroundColor(.gray)
                            Text("\(achievementManager.totalPoints)")
                                .foregroundColor(.yellow)
                                .fontWeight(.semibold)
                            Text(" points")
                                .foregroundColor(.gray)
                        }
                        .font(.system(size: 17))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 15)
                    
                    // Sport Tabs
                    HStack(spacing: 8) {
                        ForEach(SportTab.allCases, id: \.self) { tab in
                            SportTabButton(
                                title: tab.rawValue,
                                isSelected: selectedTab == tab,
                                action: { selectedTab = tab }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Achievement Content
                    AchievementContentView(selectedTab: selectedTab)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Sport Tab Button
struct SportTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.white : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color(white: 0.17), lineWidth: 1.5)
                        )
                )
        }
    }
}

// MARK: - Achievement Content View
struct AchievementContentView: View {
    let selectedTab: AchievementsView.SportTab
    @StateObject private var achievementManager = AchievementManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .all:
                    AllAchievementsContent()
                case .pb:
                    SportSpecificContent(sport: .pickleball)
                case .tennis:
                    SportSpecificContent(sport: .tennis)
                case .padel:
                    SportSpecificContent(sport: .padel)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - All Achievements Content
struct AllAchievementsContent: View {
    @StateObject private var achievementManager = AchievementManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Universal Section
            SectionHeader(title: "Universal")
            renderAchievements(for: .universal, isTiered: true)
            
            // Time-Based Section
            SectionHeader(title: "Time-Based")
            renderAchievements(for: .timeBased, isTiered: false)
            
            // Performance Section
            SectionHeader(title: "Performance")
            renderAchievements(for: .performance, isTiered: false)
            
            // Activity Section
            SectionHeader(title: "Activity")
            renderAchievements(for: .activity, isTiered: false)
            
            // Milestones Section
            SectionHeader(title: "Milestones")
            renderAchievements(for: .milestones, isTiered: false)
        }
    }
    
    @ViewBuilder
    private func renderAchievements(for category: AchievementCategory, isTiered: Bool) -> some View {
        let achievements = AchievementDefinitions.shared.definitions.values
            .filter { $0.category == category }
            .sorted { $0.name < $1.name }
        
        ForEach(achievements, id: \.type) { definition in
            if isTiered || definition.tiers.count > 1 {
                AchievementCard(
                    definition: definition,
                    progress: achievementManager.userProgress[definition.type]
                )
            } else {
                SpecialAchievementCard(
                    definition: definition,
                    progress: achievementManager.userProgress[definition.type]
                )
            }
        }
    }
}

// MARK: - Sport Specific Content
struct SportSpecificContent: View {
    let sport: AchievementCategory
    @StateObject private var achievementManager = AchievementManager.shared
    
    var achievements: [(AchievementDefinition, AchievementProgress?)] {
        AchievementDefinitions.shared.definitions.values
            .filter { $0.category == sport }
            .sorted { $0.name < $1.name }
            .map { definition in
                (definition, achievementManager.userProgress[definition.type])
            }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(achievements, id: \.0.type) { definition, progress in
                AchievementCard(
                    definition: definition,
                    progress: progress
                )
            }
            
            if achievements.isEmpty {
                Text("No \(sport.rawValue) achievements yet")
                    .foregroundColor(.gray)
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(white: 0.4))
            .tracking(0.5)
            .padding(.top, 20)
            .padding(.bottom, 12)
    }
}

// MARK: - Achievement Card (with tiers)
struct AchievementCard: View {
    let definition: AchievementDefinition
    let progress: AchievementProgress?
    
    var isLocked: Bool {
        progress?.highestTierAchieved == nil
    }
    
    var currentTier: AchievementTier? {
        progress?.highestTierAchieved
    }
    
    var nextTier: AchievementTier? {
        guard let current = currentTier else { return .regular }
        let allTiers = AchievementTier.allCases.sorted { $0.rawValue < $1.rawValue }
        guard let currentIndex = allTiers.firstIndex(of: current) else { return nil }
        return currentIndex + 1 < allTiers.count ? allTiers[currentIndex + 1] : nil
    }
    
    var progressValue: Float {
        guard let progress = progress else { return 0 }
        
        if let nextTier = nextTier,
           let nextRequirement = definition.tiers[nextTier]?.value {
            let previousValue = currentTier.flatMap { definition.tiers[$0]?.value } ?? 0
            let range = Float(nextRequirement - previousValue)
            let current = Float(progress.currentValue - previousValue)
            return min(current / range, 1.0)
        } else if currentTier == nil,
                  let firstRequirement = definition.tiers[.regular]?.value {
            return Float(progress.currentValue) / Float(firstRequirement)
        }
        
        return 1.0
    }
    
    var progressText: (current: String, next: String)? {
        guard let progress = progress else { return nil }
        
        if let nextTier = nextTier,
           let nextRequirement = definition.tiers[nextTier]?.value {
            return ("\(progress.currentValue) / \(nextRequirement)", nextTier.name + ": \(nextRequirement)")
        } else if currentTier == nil,
                  let firstRequirement = definition.tiers[.regular]?.value {
            return ("\(progress.currentValue) / \(firstRequirement)", "Regular: \(firstRequirement)")
        } else if let current = currentTier {
            return ("\(progress.currentValue)", "\(current.name) achieved!")
        }
        
        return nil
    }
    
    var totalPoints: Int {
        guard let progress = progress else { return 10 }
        
        var points = 0
        for tier in AchievementTier.allCases {
            if let achieved = progress.highestTierAchieved,
               tier.rawValue <= achieved.rawValue {
                points += tier.points
            }
        }
        return points == 0 ? 10 : points
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 16) {
                // Icon
                Text(definition.icon)
                    .font(.system(size: 40))
                    .opacity(isLocked ? 0.5 : 1.0)
                    .grayscale(isLocked ? 1.0 : 0.0)
                
                // Text Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    if let tier = currentTier {
                        // Just show tier name for achieved tiers
                        Text("\(tier.name.capitalized) tier")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    } else if let firstReq = definition.tiers[.regular] {
                        // Show clean description for locked achievements
                        Text(firstReq.description)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Right Section
                VStack(alignment: .trailing, spacing: 8) {
                    // Points
                    Text(String(totalPoints))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isLocked ? Color(white: 0.4) : .yellow)
                    
                    // Tier Dots
                    TierDots(achievedTier: currentTier)
                }
            }
            
            // Progress Bar (if not fully completed)
            if let progressInfo = progressText, currentTier?.rawValue != AchievementTier.platinum.rawValue {
                VStack(spacing: 6) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(white: 0.1))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(white: 0.5))
                                .frame(width: geometry.size.width * CGFloat(progressValue), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    // Progress Text
                    HStack {
                        Text(progressInfo.current)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(progressInfo.next)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.11))
        )
        .opacity(isLocked ? 0.4 : 1.0)
        .padding(.bottom, 12)
    }
}

// MARK: - Special Achievement Card (single tier)
struct SpecialAchievementCard: View {
    let definition: AchievementDefinition
    let progress: AchievementProgress?
    
    var isUnlocked: Bool {
        progress?.highestTierAchieved != nil
    }
    
    var tier: AchievementTier? {
        definition.tiers.keys.first
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Text(definition.icon)
                .font(.system(size: 40))
                .opacity(isUnlocked ? 1.0 : 0.5)
                .grayscale(isUnlocked ? 0.0 : 1.0)
            
            // Text Info
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                if let requirement = definition.tiers.values.first {
                    Text(isUnlocked ? "Completed" : requirement.description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Right Section
            VStack(alignment: .trailing, spacing: 8) {
                // Points
                Text(String(tier?.points ?? 0))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isUnlocked ? .yellow : Color(white: 0.4))
                
                // Tier Badge
                if let tier = tier {
                    TierBadge(tier: tier, isLocked: !isUnlocked)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.11))
        )
        .opacity(isUnlocked ? 1.0 : 0.4)
        .padding(.bottom, 12)
    }
}

// MARK: - Tier Dots
struct TierDots: View {
    let achievedTier: AchievementTier?
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(AchievementTier.allCases, id: \.self) { tier in
                Circle()
                    .fill(dotColor(for: tier))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private func dotColor(for tier: AchievementTier) -> Color {
        guard let achieved = achievedTier else {
            return Color(white: 0.1)
        }
        
        if tier.rawValue <= achieved.rawValue {
            return tier.color
        }
        
        return Color(white: 0.1)
    }
}

// MARK: - Tier Badge
struct TierBadge: View {
    let tier: AchievementTier
    let isLocked: Bool
    
    var body: some View {
        Text(tier.name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isLocked ? .gray : badgeTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isLocked ? Color(white: 0.2) : badgeBackgroundColor)
            )
    }
    
    var badgeTextColor: Color {
        switch tier {
        case .regular: return Color(hex: "#34C759")
        case .bronze: return Color(hex: "#CD7F32")
        case .silver: return Color(hex: "#C0C0C0")
        case .gold: return Color(hex: "#FFD700")
        case .platinum: return Color(hex: "#E5E4E2")
        }
    }
    
    var badgeBackgroundColor: Color {
        switch tier {
        case .regular: return Color(hex: "#34C759").opacity(0.2)
        case .bronze: return Color(hex: "#CD7F32").opacity(0.2)
        case .silver: return Color(hex: "#C0C0C0").opacity(0.2)
        case .gold: return Color(hex: "#FFD700").opacity(0.2)
        case .platinum: return Color(hex: "#E5E4E2").opacity(0.2)
        }
    }
}

// MARK: - Preview
struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
            .preferredColorScheme(.dark)
    }
}
