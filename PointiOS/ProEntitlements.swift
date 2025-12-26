import Foundation
import Combine

final class ProEntitlements: ObservableObject {
    static let shared = ProEntitlements()

    private let proKey = "ProEntitlements.isPro"
    private let defaults = UserDefaults.standard

    @Published private(set) var isPro: Bool

    private init() {
        // Load cached value initially (StoreManager will update this)
        isPro = defaults.bool(forKey: proKey)
    }

    /// Called by StoreManager when subscription status changes
    func setPro(_ enabled: Bool) {
        guard enabled != isPro else { return }
        isPro = enabled
        defaults.set(enabled, forKey: proKey)
        NotificationCenter.default.post(name: .proEntitlementsDidChange, object: nil)
        print("🔐 Pro status updated: \(enabled)")
    }

    /// Check if user has access to a specific feature
    func hasAccess(to feature: ProFeature) -> Bool {
        switch feature {
        case .unlimitedHistory:
            return isPro
        case .advancedAnalytics:
            return isPro
        case .cloudSync:
            return isPro
        case .aiInsights:
            return isPro
        case .achievements:
            return isPro
        case .dataExport:
            return isPro
        }
    }
}

// MARK: - Pro Features
enum ProFeature: String, CaseIterable {
    case unlimitedHistory = "Unlimited History"
    case advancedAnalytics = "Advanced Analytics"
    case cloudSync = "Cloud Sync"
    case aiInsights = "AI Insights"
    case achievements = "Achievements"
    case dataExport = "Data Export"

    var description: String {
        switch self {
        case .unlimitedHistory:
            return "Keep all your game history forever"
        case .advancedAnalytics:
            return "Win trends, performance graphs, and more"
        case .cloudSync:
            return "Sync across all your devices"
        case .aiInsights:
            return "AI-powered recommendations to improve"
        case .achievements:
            return "Unlock badges and track streaks"
        case .dataExport:
            return "Export your data as CSV or PDF"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedHistory: return "clock.arrow.circlepath"
        case .advancedAnalytics: return "chart.line.uptrend.xyaxis"
        case .cloudSync: return "icloud"
        case .aiInsights: return "brain"
        case .achievements: return "trophy"
        case .dataExport: return "square.and.arrow.up"
        }
    }
}

extension Notification.Name {
    static let proEntitlementsDidChange = Notification.Name("ProEntitlementsDidChange")
}
