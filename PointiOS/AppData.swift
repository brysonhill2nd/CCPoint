//
//  AppData.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/20/25.
//

import SwiftUI
import Combine

// MARK: - Appearance Mode
enum AppearanceMode: String, Codable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

class AppData: ObservableObject {
    @Published var currentUser: PointUser?
    @Published var userSettings: UserSettings = UserSettings()
    
    // Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Keys for UserDefaults
    private var settingsKey: String {
        guard let userId = currentUser?.id else { return "defaultSettings" }
        return "userSettings_\(userId)"
    }
    
    init() {
        setupAuthenticationObserver()
    }
    
    // MARK: - User-Specific Settings
    struct UserSettings: Codable {
        // Display preferences
        var displayName: String = "John Doe"
        var appearanceMode: AppearanceMode = .system

        // Sport-specific ratings
        var duprScore: String = "3.8"  // Pickleball
        var utrScore: String = "5.5"   // Tennis
        var playtomicScore: String = "4.2"  // Padel

        // Sport-specific play styles
        var pickleballPlayStyle: PickleballPlayStyle = .dinker
        var tennisPlayStyle: TennisPlayStyle = .tacticalBaseliner
        var padelPlayStyle: PadelPlayStyle = .wallDefender

        // App preferences
        var hapticFeedback: Bool = true
        var soundEffects: Bool = false

        // Sport-specific game settings
        var pickleballSettings: SportGameSettings = SportGameSettings(sport: "Pickleball")
        var tennisSettings: SportGameSettings = SportGameSettings(sport: "Tennis")
        var padelSettings: SportGameSettings = SportGameSettings(sport: "Padel")
    }
    
    // MARK: - Sport Game Settings
    struct SportGameSettings: Codable {
        var scoreLimit: Int?
        var winByTwo: Bool
        var matchFormat: String
        var preferredGameType: String
        
        init(sport: String) {
            switch sport {
            case "Pickleball":
                scoreLimit = 11
                winByTwo = true
                matchFormat = "bestOf3"
                preferredGameType = "doubles"
            case "Tennis":
                scoreLimit = nil
                winByTwo = true
                matchFormat = "bestOf3"
                preferredGameType = "singles"
            case "Padel":
                scoreLimit = nil
                winByTwo = true
                matchFormat = "bestOf3"
                preferredGameType = "doubles"
            default:
                scoreLimit = 21
                winByTwo = true
                matchFormat = "single"
                preferredGameType = "singles"
            }
        }
    }
    
    // MARK: - Computed Properties (for backwards compatibility)
    var displayName: String {
        get { userSettings.displayName }
        set {
            userSettings.displayName = newValue
            saveSettings()
        }
    }
    
    var duprScore: String {
        get { userSettings.duprScore }
        set {
            userSettings.duprScore = newValue
            saveSettings()
        }
    }
    
    var utrScore: String {
        get { userSettings.utrScore }
        set {
            userSettings.utrScore = newValue
            saveSettings()
        }
    }
    
    var playtomicScore: String {
        get { userSettings.playtomicScore }
        set {
            userSettings.playtomicScore = newValue
            saveSettings()
        }
    }
    
    var pickleballPlayStyle: PickleballPlayStyle {
        get { userSettings.pickleballPlayStyle }
        set {
            userSettings.pickleballPlayStyle = newValue
            saveSettings()
        }
    }
    
    var tennisPlayStyle: TennisPlayStyle {
        get { userSettings.tennisPlayStyle }
        set {
            userSettings.tennisPlayStyle = newValue
            saveSettings()
        }
    }
    
    var padelPlayStyle: PadelPlayStyle {
        get { userSettings.padelPlayStyle }
        set {
            userSettings.padelPlayStyle = newValue
            saveSettings()
        }
    }
    
    var hapticFeedback: Bool {
        get { userSettings.hapticFeedback }
        set {
            userSettings.hapticFeedback = newValue
            saveSettings()
        }
    }
    
    var soundEffects: Bool {
        get { userSettings.soundEffects }
        set {
            userSettings.soundEffects = newValue
            saveSettings()
        }
    }
    
    // MARK: - Authentication Observer
    private func setupAuthenticationObserver() {
        AuthenticationManager.shared.$currentUser
            .sink { [weak self] user in
                self?.handleUserChange(user)
            }
            .store(in: &cancellables)
    }
    
    private func handleUserChange(_ user: PointUser?) {
        currentUser = user
        
        if let user = user {
            // Load user-specific settings
            loadSettings()
            
            // Update display name from user profile
            if userSettings.displayName == "John Doe" {
                userSettings.displayName = user.displayName
            }
            
            // Update scores from user profile if available
            if let dupr = user.duprScore {
                userSettings.duprScore = dupr
            }
            if let utr = user.utrScore {
                userSettings.utrScore = utr
            }
            if let playtomic = user.playtomicScore {
                userSettings.playtomicScore = playtomic
            }
            
            // Update play styles from user profile if available
            if let pbStyle = user.pickleballPlayStyle,
               let style = PickleballPlayStyle(rawValue: pbStyle) {
                userSettings.pickleballPlayStyle = style
            }
            if let tennisStyle = user.tennisPlayStyle,
               let style = TennisPlayStyle(rawValue: tennisStyle) {
                userSettings.tennisPlayStyle = style
            }
            if let padelStyle = user.padelPlayStyle,
               let style = PadelPlayStyle(rawValue: padelStyle) {
                userSettings.padelPlayStyle = style
            }
            
            saveSettings()
        } else {
            // User logged out - reset to defaults
            userSettings = UserSettings()
        }
    }
    
    // MARK: - Settings Persistence
    func saveSettings() {
        guard currentUser != nil else { return }
        
        if let encoded = try? JSONEncoder().encode(userSettings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
        
        // Also sync to CompleteUserHealthManager if available
        if CompleteUserHealthManager.shared.currentUser != nil {
            CompleteUserHealthManager.shared.updateUserData { user in
                user.hapticFeedback = userSettings.hapticFeedback
                user.soundEffects = userSettings.soundEffects
                
                // Update sport settings
                user.pickleballSettings = CompleteUserHealthManager.EnhancedPointUser.SportSettings(
                    scoreLimit: userSettings.pickleballSettings.scoreLimit,
                    winByTwo: userSettings.pickleballSettings.winByTwo,
                    matchFormat: userSettings.pickleballSettings.matchFormat,
                    preferredGameType: userSettings.pickleballSettings.preferredGameType
                )
                
                user.tennisSettings = CompleteUserHealthManager.EnhancedPointUser.SportSettings(
                    scoreLimit: userSettings.tennisSettings.scoreLimit,
                    winByTwo: userSettings.tennisSettings.winByTwo,
                    matchFormat: userSettings.tennisSettings.matchFormat,
                    preferredGameType: userSettings.tennisSettings.preferredGameType
                )
                
                user.padelSettings = CompleteUserHealthManager.EnhancedPointUser.SportSettings(
                    scoreLimit: userSettings.padelSettings.scoreLimit,
                    winByTwo: userSettings.padelSettings.winByTwo,
                    matchFormat: userSettings.padelSettings.matchFormat,
                    preferredGameType: userSettings.padelSettings.preferredGameType
                )
            }
        }
    }
    
    // Expose a safe, explicit API for views to persist settings changes
    public func persistUserSettings() {
        saveSettings()
    }
    
    private func loadSettings() {
        guard currentUser != nil else { return }
        
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            userSettings = decoded
        }
    }
    
    // MARK: - Update Methods
    func updatePlayStyle(for sport: String, style: String) {
        switch sport {
        case "Pickleball":
            if let pbStyle = PickleballPlayStyle(rawValue: style) {
                pickleballPlayStyle = pbStyle
            }
        case "Tennis":
            if let tStyle = TennisPlayStyle(rawValue: style) {
                tennisPlayStyle = tStyle
            }
        case "Padel":
            if let pStyle = PadelPlayStyle(rawValue: style) {
                padelPlayStyle = pStyle
            }
        default:
            break
        }
    }
    
    func updateScore(for sport: String, score: String) {
        switch sport {
        case "Pickleball":
            duprScore = score
        case "Tennis":
            utrScore = score
        case "Padel":
            playtomicScore = score
        default:
            break
        }
    }
}

// MARK: - Pickleball Play Styles
enum PickleballPlayStyle: String, CaseIterable, Codable {
    case dinker = "dinker"
    case banger = "banger"
    case allcourt = "allcourt"
    
    var name: String {
        switch self {
        case .dinker: return "Dinker"
        case .banger: return "Banger"
        case .allcourt: return "All-Court"
        }
    }
    
    var emoji: String {
        switch self {
        case .dinker: return "🐌"
        case .banger: return "💥"
        case .allcourt: return "🏃"
        }
    }
    
    var description: String {
        switch self {
        case .dinker: return "Soft game, placement over power"
        case .banger: return "Power player, aggressive shots"
        case .allcourt: return "Balanced, adapts to any situation"
        }
    }
}

// MARK: - Tennis Play Styles
enum TennisPlayStyle: String, CaseIterable, Codable {
    case powerBaseliner = "powerBaseliner"
    case tacticalBaseliner = "tacticalBaseliner"
    case counterpuncher = "counterpuncher"
    case allCourtAttacker = "allCourtAttacker"
    case serveAndVolleyer = "serveAndVolleyer"
    case tactician = "tactician"
    
    var name: String {
        switch self {
        case .powerBaseliner: return "Power Baseliner"
        case .tacticalBaseliner: return "Tactical Baseliner"
        case .counterpuncher: return "Counterpuncher"
        case .allCourtAttacker: return "All-Court Attacker"
        case .serveAndVolleyer: return "Serve-and-Volleyer"
        case .tactician: return "The Tactician"
        }
    }
    
    var emoji: String {
        switch self {
        case .powerBaseliner: return "💥"
        case .tacticalBaseliner: return "🔄"
        case .counterpuncher: return "🛡️"
        case .allCourtAttacker: return "🏃‍♂️"
        case .serveAndVolleyer: return "⚡️"
        case .tactician: return "🧠"
        }
    }
    
    var description: String {
        switch self {
        case .powerBaseliner: return "Dictates with overwhelming pace and flat, deep groundstrokes"
        case .tacticalBaseliner: return "Constructs points using heavy spin, angles, and consistency"
        case .counterpuncher: return "A defensive wall with elite speed and court coverage"
        case .allCourtAttacker: return "Aggressively looks for short balls to approach the net"
        case .serveAndVolleyer: return "Classic net rusher who uses serve to set up volleys"
        case .tactician: return "Wins by disrupting rhythm with slices, drops, and lobs"
        }
    }
}

// MARK: - Padel Play Styles
enum PadelPlayStyle: String, CaseIterable, Codable {
    case aggressor = "aggressor"
    case wallDefender = "wallDefender"
    case netDominator = "netDominator"
    case controller = "controller"
    case counterAttacker = "counterAttacker"
    case tacticalPlayer = "tacticalPlayer"
    
    var name: String {
        switch self {
        case .aggressor: return "Aggressor"
        case .wallDefender: return "Wall Defender"
        case .netDominator: return "Net Dominator"
        case .controller: return "Controller"
        case .counterAttacker: return "Counter-Attacker"
        case .tacticalPlayer: return "Tactical Player"
        }
    }
    
    var emoji: String {
        switch self {
        case .aggressor: return "🔥"
        case .wallDefender: return "🧱"
        case .netDominator: return "🕸️"
        case .controller: return "🎯"
        case .counterAttacker: return "⚔️"
        case .tacticalPlayer: return "♟️"
        }
    }
    
    var description: String {
        switch self {
        case .aggressor: return "Constant pressure with powerful shots and aggressive positioning"
        case .wallDefender: return "Master of wall play, incredible defense and patience"
        case .netDominator: return "Controls the net with quick reflexes and sharp volleys"
        case .controller: return "Dictates pace and placement, minimal unforced errors"
        case .counterAttacker: return "Turns defense into offense with explosive counters"
        case .tacticalPlayer: return "Strategic player who exploits opponents' weaknesses"
        }
    }
}

// Extension to make SportSettings work with CompleteUserHealthManager
extension CompleteUserHealthManager.EnhancedPointUser.SportSettings {
    init(scoreLimit: Int?, winByTwo: Bool, matchFormat: String, preferredGameType: String) {
        self.scoreLimit = scoreLimit
        self.winByTwo = winByTwo
        self.matchFormat = matchFormat
        self.preferredGameType = preferredGameType
    }
}

