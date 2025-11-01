//
//  PointUser.swift
//  PointiOS
//
//  User model for Firebase
//

import Foundation
import FirebaseFirestore

// MARK: - User Model
struct PointUser: Codable {
    let id: String
    var displayName: String
    var email: String
    var duprScore: String?
    var utrScore: String?
    var playtomicScore: String?
    var pickleballPlayStyle: String?
    var tennisPlayStyle: String?
    var padelPlayStyle: String?
    var profileImageURL: String?
    var createdAt: Date
    var lastUpdated: Date
    
    // Stats
    var totalGamesPlayed: Int = 0
    var totalWins: Int = 0
    var achievements: [String] = []
    var favoriteCourtLocation: String?
    
    // Computed properties
    var winPercentage: Double {
        guard totalGamesPlayed > 0 else { return 0 }
        return Double(totalWins) / Double(totalGamesPlayed) * 100
    }
    
    var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: displayName) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        
        // Fallback to first letters
        let names = displayName.split(separator: " ")
        let initials = names.prefix(2).map { String($0.prefix(1)) }.joined()
        return initials.uppercased()
    }
}
 
