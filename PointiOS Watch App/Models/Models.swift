//
//  Models.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//
import SwiftUI
import Foundation

// MARK: - Basic Enums
enum Player: CaseIterable, CustomStringConvertible {
    case player1, player2
    
    var description: String {
        switch self {
        case .player1: return "Player1"
        case .player2: return "Player2"
        }
    }
}

enum GameType: Hashable {
    case singles, doubles
}

// MARK: - Sport Type
enum SportType: String, CaseIterable, Identifiable {
    case pickleball = "Pickleball"
    case tennis = "Tennis"
    case padel = "Padel"
    
    var id: String { rawValue }
}

// MARK: - Game Action for Undo System
enum GameAction {
    case point(player: Player)
    case serve
    case gameWin(player: Player, prevScore1: Int, prevScore2: Int)
    case gameWon(player: Player)  // For Tennis/Padel
    case setWon(player: Player)   // For Tennis/Padel
}

// MARK: - Color Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // App-specific colors
    static let emptyServiceGray = Color(hex: "656363")
    static let filledServiceGreen = Color(hex: "CFFE76")
}
