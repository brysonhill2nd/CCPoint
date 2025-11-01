//
//  NavigationManager.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//

import SwiftUI

class NavigationManager: ObservableObject {
    @Published var navigationPath = NavigationPath()
    
    func navigateToHome() {
        print("🏠 Navigating to home - clearing navigation stack")
        navigationPath = NavigationPath()
    }
    
    func navigateToGameType() {
        navigationPath.append(NavigationTarget.gameTypeSelection)
    }
    
    func navigateToSport(_ sport: SportType) {
        navigationPath.append(NavigationTarget.sportSelection(sport))
    }
}

// Navigation targets
enum NavigationTarget: Hashable {
    case gameTypeSelection
    case settings
    case history
    case sportSelection(SportType)
    case tennisFormat
    case padelFirstServer
}
