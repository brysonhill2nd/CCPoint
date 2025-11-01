//
//  PadelSettings.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//
import Foundation
import SwiftUI

class PadelSettings: ObservableObject {
    
    enum ScoringSystem: String, CaseIterable, Identifiable {
        case traditional = "Traditional"  // 15-30-40
        case numerical = "Numerical"      // 1-2-3-4
        
        var id: String { rawValue }
    }
    
    // Define our own MatchFormatType enum
    enum MatchFormatType: String, CaseIterable, Identifiable {
        case single = "Single Game"
        case bestOf3 = "Best of 3"
        case bestOf5 = "Best of 5"
        case firstTo = "First To..."
        case unlimited = "Unlimited Games"
        
        var id: String { self.rawValue }
    }
    
    @AppStorage("padelScoringSystem") var scoringSystem: ScoringSystem = .traditional {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("padelGoldenPoint") var goldenPoint: Bool = true {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("padelMatchFormatType") var matchFormatType: MatchFormatType = .bestOf3 {
        willSet { objectWillChange.send() }
    }
       
    @AppStorage("padelFirstToGamesCount") var firstToGamesCount: Int = 2 {
        willSet { objectWillChange.send() }
    }
    
    // Helper method to get games needed to win match
    func getGamesNeededToWinMatch() -> Int? {
        switch matchFormatType {
        case .single: return 1
        case .bestOf3: return 2
        case .bestOf5: return 3
        case .firstTo: return firstToGamesCount > 0 ? firstToGamesCount : nil
        case .unlimited: return nil
        }
    }
       
    // Helper method to format scores
    func formatScore(_ points: Int, opponentPoints: Int = 0, isInTiebreak: Bool = false) -> String {
        // In tiebreak, always show numerical scores
        if isInTiebreak {
            return "\(points)"
        }
        
        switch scoringSystem {
        case .traditional:
            // At deuce, both show 40
            if points >= 3 && opponentPoints >= 3 {
                if points == opponentPoints {
                    return "40" // Both show 40 at deuce
                } else if points > opponentPoints {
                    return "AD" // Advantage
                } else {
                    return "40"
                }
            } else {
                // Normal scoring
                switch points {
                case 0: return "0"
                case 1: return "15"
                case 2: return "30"
                case 3: return "40"
                default: return "40"
                }
            }
        case .numerical:
            return "\(points)"
        }
    }
}
