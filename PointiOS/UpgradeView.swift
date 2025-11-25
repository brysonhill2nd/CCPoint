import SwiftUI

struct UpgradeView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var pro = ProEntitlements.shared
    
    private let monthlyPrice = "$2.99 / month"
    private let yearlyPrice = "$19.99 / year"
    
    private let featureGroups: [(title: String, items: [String])] = [
        ("Advanced Analytics", [
            "Win percentage trends",
            "Court & location performance",
            "Time-of-day analysis",
            "Serve & return breakdowns"
        ]),
        ("History & Sync", [
            "Unlimited game history",
            "Cloud backup & cross-device sync",
            "Data export (CSV, PDF)"
        ]),
        ("Insights & Charts", [
            "AI-generated recommendations",
            "Donut charts & performance graphs",
            "Sport distribution analysis"
        ]),
        ("Gamification", [
            "Achievements & streaks",
            "XP leveling system",
            "Leaderboards (coming soon)"
        ])
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    pricingCards
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(featureGroups, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.title)
                                    .font(.headline)
                                ForEach(group.items, id: \.self) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.accentColor)
                                        Text(item)
                                    }
                                    .font(.subheadline)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }
                    }
                    
                    Button(action: activatePro) {
                        Text("Unlock Point Pro")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Point Pro")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            Text("Upgrade to Point Pro")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Unlock deeper stats, unlimited history, AI-powered insights, and premium sync.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var pricingCards: some View {
        VStack(spacing: 12) {
            PricingCard(title: "Monthly", price: monthlyPrice, badge: "Start anytime")
            PricingCard(title: "Yearly", price: yearlyPrice, badge: "Best value")
        }
    }
    
    private func activatePro() {
        // Temporary mock purchase
        pro.setPro(true)
        dismiss()
    }
}

struct PricingCard: View {
    let title: String
    let price: String
    let badge: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(badge)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(999)
            }
            Text(price)
                .font(.title3)
                .fontWeight(.bold)
            Text("Cancel anytime. Prices shown in USD.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct LockedFeatureCard: View {
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("PRO")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(8)
            }
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Button(action: action) {
                Text("Unlock Pro")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(18)
    }
}
