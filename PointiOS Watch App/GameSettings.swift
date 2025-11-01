//
//  GameSettings.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//

import Foundation
import SwiftUI

class GameSettings: ObservableObject {
    
    // MARK: - Score Settings
    @AppStorage("scoreLimitRawValue") var scoreLimitRawValue: Int = 11 {
        willSet { objectWillChange.send() }
    }
    
    var scoreLimit: Int? {
        get {
            if scoreLimitRawValue == 0 { return nil } // Unlimited
            else if scoreLimitRawValue > 0 { return scoreLimitRawValue }
            else { return nil }
        }
        set {
            scoreLimitRawValue = newValue ?? 0
        }
    }
    
    @AppStorage("winByTwo") var winByTwo: Bool = true {
        willSet { objectWillChange.send() }
    }
    
    // MARK: - Match Format
    enum MatchFormatType: String, CaseIterable, Identifiable {
        case single = "Single Game"
        case bestOf3 = "Best of 3"
        case bestOf5 = "Best of 5"
        case firstTo = "First To..."
        case unlimited = "Unlimited Games"
        
        var id: String { self.rawValue }
    }
    
    @AppStorage("matchFormatType") var matchFormatType: MatchFormatType = .single {
        willSet { objectWillChange.send() }
    }
    
    @AppStorage("firstToGamesCount") var firstToGamesCount: Int = 2 {
        willSet { objectWillChange.send() }
    }
    
    // MARK: - Helper Functions
    func getGamesNeededToWinMatch() -> Int? {
        switch matchFormatType {
        case .single: return 1
        case .bestOf3: return 2
        case .bestOf5: return 3
        case .firstTo: return firstToGamesCount > 0 ? firstToGamesCount : nil
        case .unlimited: return nil
        }
    }
}

