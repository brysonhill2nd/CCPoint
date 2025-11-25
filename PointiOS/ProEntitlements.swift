import Foundation
import Combine

final class ProEntitlements: ObservableObject {
    static let shared = ProEntitlements()
    
    private let proKey = "ProEntitlements.isPro"
    private let defaults = UserDefaults.standard
    
    @Published private(set) var isPro: Bool
    
    private init() {
        isPro = defaults.bool(forKey: proKey)
    }
    
    func setPro(_ enabled: Bool) {
        guard enabled != isPro else { return }
        isPro = enabled
        defaults.set(enabled, forKey: proKey)
        NotificationCenter.default.post(name: .proEntitlementsDidChange, object: nil)
    }
}

extension Notification.Name {
    static let proEntitlementsDidChange = Notification.Name("ProEntitlementsDidChange")
}
