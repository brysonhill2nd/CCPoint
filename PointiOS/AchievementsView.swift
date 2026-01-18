//
//  AchievementsView.swift
//  PointiOS
//
//  Swiss Design Achievements View
//

import SwiftUI

struct AchievementsView: View {
    @StateObject private var achievementManager = AchievementManager.shared
    @Environment(\.adaptiveColors) var colors
    @Environment(\.dismiss) var dismiss
    @State private var selectedStatus: StatusFilter = .all
    @State private var selectedSport: SportFilter = .all

    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case unlocked = "Unlocked"
        case inProgress = "In Progress"
        case locked = "Locked"
    }

    enum SportFilter: String, CaseIterable {
        case all = "All Sports"
        case pickleball = "Pickleball"
        case tennis = "Tennis"
        case padel = "Padel"

        var category: AchievementCategory? {
            switch self {
            case .all: return nil
            case .pickleball: return .pickleball
            case .tennis: return .tennis
            case .padel: return .padel
            }
        }
    }

    var unlockedCount: Int {
        sportFilteredAchievements.filter { $0.1?.highestTierAchieved != nil }.count
    }

    var totalAchievements: Int {
        sportFilteredAchievements.count
    }

    var sportFilteredAchievements: [(AchievementDefinition, AchievementProgress?)] {
        let all = AchievementDefinitions.shared.definitions.values
            .sorted { $0.name < $1.name }
            .map { ($0, achievementManager.userProgress[$0.type]) }

        if let category = selectedSport.category {
            return all.filter { $0.0.category == category || $0.0.category == .universal }
        }
        return all
    }

    var filteredAchievements: [(AchievementDefinition, AchievementProgress?)] {
        let sportFiltered = sportFilteredAchievements

        switch selectedStatus {
        case .all:
            return sportFiltered
        case .unlocked:
            return sportFiltered.filter { $0.1?.highestTierAchieved != nil }
        case .inProgress:
            return sportFiltered.filter { progress in
                guard let p = progress.1 else { return false }
                return p.highestTierAchieved == nil && p.currentValue > 0
            }
        case .locked:
            return sportFiltered.filter { progress in
                guard let p = progress.1 else { return true }
                return p.highestTierAchieved == nil && p.currentValue == 0
            }
        }
    }

    var body: some View {
        ZStack {
            colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(colors.textPrimary)
                        }
                        Spacer()
                    }

                    Text("Achievements")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(colors.textPrimary)

                    HStack(spacing: 16) {
                        Text("\(unlockedCount)/\(totalAchievements)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(SwissColors.green)
                        +
                        Text(" unlocked")
                            .font(.system(size: 14))
                            .foregroundColor(colors.textSecondary)

                        Text("•")
                            .foregroundColor(colors.textSecondary)

                        Text("\(achievementManager.totalPoints)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(SwissColors.green)
                        +
                        Text(" points")
                            .font(.system(size: 14))
                            .foregroundColor(colors.textSecondary)
                    }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)

                    // Sport Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sport")
                            .font(SwissTypography.monoLabel(11))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(SportFilter.allCases, id: \.self) { sport in
                                    FilterPill(
                                        label: sport.rawValue,
                                        isSelected: selectedSport == sport,
                                        colors: colors
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedSport = sport
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Status Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(SwissTypography.monoLabel(11))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(StatusFilter.allCases, id: \.self) { filter in
                                    FilterPill(
                                        label: filter.rawValue,
                                        count: countForFilter(filter),
                                        isSelected: selectedStatus == filter,
                                        colors: colors
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedStatus = filter
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Achievements List
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Achievements")
                            .font(SwissTypography.monoLabel(11))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(colors.textSecondary)

                        if filteredAchievements.isEmpty {
                            VStack(spacing: 8) {
                                Text("No achievements found")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(colors.textSecondary)
                                Text("Keep playing to unlock achievements")
                                    .font(.system(size: 12))
                                    .foregroundColor(colors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(filteredAchievements.enumerated()), id: \.element.0.type) { index, item in
                                    AchievementRow(
                                        definition: item.0,
                                        progress: item.1
                                    )
                                    .padding(.vertical, 12)

                                    if index < filteredAchievements.count - 1 {
                                        Rectangle()
                                            .fill(colors.borderSubtle)
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
                .padding(.horizontal, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func countForFilter(_ filter: StatusFilter) -> Int {
        let sportFiltered = sportFilteredAchievements

        switch filter {
        case .all:
            return sportFiltered.count
        case .unlocked:
            return sportFiltered.filter { $0.1?.highestTierAchieved != nil }.count
        case .inProgress:
            return sportFiltered.filter { progress in
                guard let p = progress.1 else { return false }
                return p.highestTierAchieved == nil && p.currentValue > 0
            }.count
        case .locked:
            return sportFiltered.filter { progress in
                guard let p = progress.1 else { return true }
                return p.highestTierAchieved == nil && p.currentValue == 0
            }.count
        }
    }
}

// MARK: - Achievement Row
private struct AchievementRow: View {
    @Environment(\.adaptiveColors) var colors
    let definition: AchievementDefinition
    let progress: AchievementProgress?

    var isLocked: Bool {
        progress?.highestTierAchieved == nil && (progress?.currentValue ?? 0) == 0
    }

    var isUnlocked: Bool {
        progress?.highestTierAchieved != nil
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
            return min(max(current / range, 0), 1.0)
        } else if currentTier == nil,
                  let firstRequirement = definition.tiers[.regular]?.value {
            return min(Float(progress.currentValue) / Float(firstRequirement), 1.0)
        }

        return 1.0
    }

    var progressText: String? {
        guard let progress = progress else { return nil }

        if let nextTier = nextTier,
           let nextRequirement = definition.tiers[nextTier]?.value {
            return "\(progress.currentValue)/\(nextRequirement)"
        } else if currentTier == nil,
                  let firstRequirement = definition.tiers[.regular]?.value {
            return "\(progress.currentValue)/\(firstRequirement)"
        }

        return nil
    }

    var earnedPoints: Int {
        guard let progress = progress else { return 0 }

        var points = 0
        for tier in AchievementTier.allCases {
            if let achieved = progress.highestTierAchieved,
               tier.rawValue <= achieved.rawValue {
                points += tier.points
            }
        }
        return points
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Text(definition.icon)
                .font(.system(size: 32))
                .opacity(isLocked ? 0.4 : 1.0)
                .grayscale(isLocked ? 1.0 : 0.0)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(definition.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colors.textPrimary)

                    if let tier = currentTier {
                        Text(tier.name.uppercased())
                            .font(SwissTypography.monoLabel(9))
                            .tracking(0.5)
                            .foregroundColor(tier.color)
                    }
                }

                if let firstReq = definition.tiers[.regular] {
                    Text(firstReq.description)
                        .font(.system(size: 12))
                        .foregroundColor(colors.textSecondary)
                        .lineLimit(1)
                }

                // Progress bar (if not fully completed)
                if !isUnlocked || nextTier != nil {
                    HStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colors.surface)
                                    .frame(height: 3)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isUnlocked ? SwissColors.green : colors.textTertiary)
                                    .frame(width: geometry.size.width * CGFloat(progressValue), height: 3)
                            }
                        }
                        .frame(height: 3)

                        if let progressText = progressText {
                            Text(progressText)
                                .font(SwissTypography.monoLabel(9))
                                .foregroundColor(colors.textTertiary)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            // Points
            if earnedPoints > 0 {
                Text("+\(earnedPoints)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(SwissColors.green)
            }
        }
        .opacity(isLocked ? 0.5 : 1.0)
    }
}

// MARK: - Filter Pill
private struct FilterPill: View {
    let label: String
    var count: Int? = nil
    let isSelected: Bool
    let colors: SwissAdaptiveColors
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))

                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
            }
            .foregroundColor(isSelected ? colors.textPrimary : colors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? colors.surface : colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? SwissColors.green : colors.borderSubtle, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
    }
}
