//
//  ShotAnalyticsCard.swift
//  PointiOS
//
//  Shot distribution and analytics display
//

import SwiftUI

// MARK: - Shot Distribution Card
struct ShotDistributionCard: View {
    let game: WatchGameRecord
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if let analytics = InsightsEngine.shared.analyze(game: game) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Shot Analysis")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    if let shots = game.shots {
                        Text("\(shots.count) shots")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                // Shot Distribution Donut Chart
                if !analytics.distribution.isEmpty {
                    let chartData = analytics.distribution.map { type, count in
                        DonutChartData(
                            label: type.displayName(for: game.sportType, isBackhand: false),
                            value: Double(count),
                            color: colorForShotType(type),
                            icon: type.icon
                        )
                    }.sorted { $0.value > $1.value }

                    DonutChart(
                        data: chartData,
                        centerText: "\(analytics.distribution.values.reduce(0, +))",
                        size: 160,
                        lineWidth: 28
                    )
                }

                // Winning Shots Section
                if !analytics.winningShots.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Winning Shots")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        ForEach(analytics.winningShots.sorted(by: { $0.value.percentage > $1.value.percentage }), id: \.key) { type, winRate in
                            if winRate.total >= 3 {  // Only show if enough data
                                HStack {
                                    Text(type.icon)
                                    Text(type.displayName(for: game.sportType, isBackhand: false))
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Text("\(winRate.wins)/\(winRate.total)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("\(Int(winRate.percentage))%")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(winRate.percentage >= 60 ? .green : .primary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                // Rally Reaction Time
                if let avgReactionTime = analytics.averageRallyReactionTime {
                    HStack {
                        Text("Avg Rally Reaction")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1fs", avgReactionTime))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // AI Insights
                if !analytics.topInsights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insights")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        ForEach(analytics.topInsights, id: \.self) { insight in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple)
                                Text(insight)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.1),
                                Color.blue.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            .padding(20)
            .background(cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        } else {
            EmptyView()
        }
    }

    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(.systemGray6)
            } else {
                Color.white
            }
        }
    }

    private func colorForShotType(_ type: ShotType) -> Color {
        switch type {
        case .serve: return .blue
        case .powerShot: return .orange
        case .overhead: return .red
        case .volley: return .purple
        case .touchShot: return .green
        case .unknown: return .gray
        }
    }
}

// MARK: - Shot Power Stats Card
struct PowerStatsCard: View {
    let shots: [StoredShot]
    let shotType: ShotType
    let sport: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if let stats = InsightsEngine.shared.powerStats(for: shots, shotType: shotType) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(shotType.icon)
                    Text(shotType.displayName(for: sport, isBackhand: false))
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }

                HStack(spacing: 20) {
                    ShotStatItem(label: "Avg", value: String(format: "%.1fg", stats.average))
                    ShotStatItem(label: "Peak", value: String(format: "%.1fg", stats.peak))
                    ShotStatItem(label: "Consistency", value: consistencyRating(stats.consistency))
                }
            }
            .padding(16)
            .background(cardBackground)
            .cornerRadius(12)
        }
    }

    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(.systemGray6)
            } else {
                Color.white
            }
        }
    }

    private func consistencyRating(_ stdDev: Double) -> String {
        if stdDev < 0.3 {
            return "★★★"
        } else if stdDev < 0.6 {
            return "★★☆"
        } else {
            return "★☆☆"
        }
    }
}

struct ShotStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Pro Feature Gate
struct LockedShotAnalyticsCard: View {
    let onUpgrade: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple)
                .opacity(0.3)

            Text("Shot Analytics")
                .font(.system(size: 20, weight: .bold))

            Text("Unlock detailed shot tracking, winning shot analysis, and AI-powered insights")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onUpgrade) {
                Text("Upgrade to Pro")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }

    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                Color(.systemGray6)
            } else {
                Color.white
            }
        }
    }
}
