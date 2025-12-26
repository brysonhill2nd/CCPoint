//
//  SwissDesignSystem.swift
//  PointiOS
//
//  Swiss Minimalist Design System
//  Inspired by International Typographic Style
//

import SwiftUI

// MARK: - Swiss Colors
struct SwissColors {
    static let black = Color.black
    static let white = Color.white
    static let gray = Color(red: 0.898, green: 0.906, blue: 0.922) // #E5E7EB

    // Point Brand Green - Primary accent color
    static let green = Color(red: 0.420, green: 0.620, blue: 0.243) // #6B9E3E
    static let greenLight = Color(red: 0.420, green: 0.620, blue: 0.243).opacity(0.15) // Light tint
    static let greenMuted = Color(red: 0.420, green: 0.620, blue: 0.243).opacity(0.6) // Muted version

    static let red = Color(red: 0.725, green: 0.110, blue: 0.110) // #B91C1C
    static let yellow = Color(red: 0.945, green: 0.769, blue: 0.059) // #F1C40F - Warning/In-Progress

    // Grays for hierarchy (WCAG AA compliant on white background)
    // Using fixed colors to avoid dark mode adaptation issues
    static let gray50 = Color(red: 0.97, green: 0.97, blue: 0.98)   // #F8F8FA - Lightest
    static let gray100 = Color(red: 0.94, green: 0.94, blue: 0.96)  // #F0F0F5 - Very light
    static let gray200 = Color(red: 0.88, green: 0.88, blue: 0.90)  // #E0E0E6 - Light
    static let gray300 = Color(red: 0.78, green: 0.78, blue: 0.80)  // #C7C7CC - Medium light
    static let gray400 = Color(red: 0.55, green: 0.55, blue: 0.58)  // #8C8C94 - Medium ~4.5:1 contrast
    static let gray500 = Color(red: 0.40, green: 0.40, blue: 0.42)  // #666666 - Dark ~7:1 contrast

    // Accessible text colors (use these for labels) - WCAG AA compliant
    static let textPrimary = Color(red: 0.2, green: 0.2, blue: 0.2)    // #333333 - 12.6:1 contrast
    static let textSecondary = Color(red: 0.35, green: 0.35, blue: 0.35) // #595959 - 7.5:1 contrast
    static let textTertiary = Color(red: 0.45, green: 0.45, blue: 0.45)  // #737373 - 5.0:1 contrast
    static let textMuted = Color(red: 0.55, green: 0.55, blue: 0.55)     // #8C8C8C - 3.9:1 contrast (decorative only)

    // Semantic
    static let win = green
    static let loss = red
    static let accent = green  // Changed from black to green
    static let primary = black

    // MARK: - Dark Mode Colors
    // Background: #0A0A0A (near-black)
    static let darkBackground = Color(red: 0.039, green: 0.039, blue: 0.039) // #0A0A0A
    static let darkSurface = Color(red: 0.078, green: 0.078, blue: 0.078) // #141414
    static let darkBorder = Color.white
    static let darkBorderSubtle = Color.white.opacity(0.2)
    static let darkBorderMuted = Color.white.opacity(0.1)

    // Dark mode text colors
    static let darkTextPrimary = Color.white
    static let darkTextSecondary = Color(red: 0.6, green: 0.6, blue: 0.6) // #999999
    static let darkTextTertiary = Color(red: 0.5, green: 0.5, blue: 0.5) // #808080
    static let darkTextMuted = Color(red: 0.4, green: 0.4, blue: 0.4) // #666666
}

// MARK: - Adaptive Colors (responds to dark mode)
struct SwissAdaptiveColors {
    let isDarkMode: Bool

    // Backgrounds
    var background: Color { isDarkMode ? SwissColors.darkBackground : SwissColors.white }
    var surface: Color { isDarkMode ? SwissColors.darkSurface : SwissColors.white }
    var cardBackground: Color { isDarkMode ? SwissColors.darkSurface : SwissColors.white }

    // Borders
    var border: Color { isDarkMode ? SwissColors.darkBorder : SwissColors.black }
    var borderSubtle: Color { isDarkMode ? SwissColors.darkBorderSubtle : SwissColors.gray }
    var borderMuted: Color { isDarkMode ? SwissColors.darkBorderMuted : SwissColors.gray.opacity(0.5) }

    // Text
    var textPrimary: Color { isDarkMode ? SwissColors.darkTextPrimary : SwissColors.textPrimary }
    var textSecondary: Color { isDarkMode ? SwissColors.darkTextSecondary : SwissColors.textSecondary }
    var textTertiary: Color { isDarkMode ? SwissColors.darkTextTertiary : SwissColors.textTertiary }
    var textMuted: Color { isDarkMode ? SwissColors.darkTextMuted : SwissColors.textMuted }

    // Primary colors (inverted for contrast)
    var primary: Color { isDarkMode ? SwissColors.white : SwissColors.black }
    var primaryInverted: Color { isDarkMode ? SwissColors.black : SwissColors.white }

    // Semantic (green/red stay the same)
    var win: Color { SwissColors.green }
    var loss: Color { SwissColors.red }
    var accent: Color { SwissColors.green }

    // Hover/Press states
    var hoverBackground: Color { isDarkMode ? Color.white.opacity(0.05) : SwissColors.gray50 }
    var pressBackground: Color { isDarkMode ? Color.white.opacity(0.1) : SwissColors.gray100 }

    // Input fields
    var inputBackground: Color { isDarkMode ? Color.white.opacity(0.05) : SwissColors.white }
    var inputBorder: Color { isDarkMode ? SwissColors.darkBorderSubtle : SwissColors.gray }
}

// MARK: - Environment Key for Dark Mode
struct DarkModeKey: EnvironmentKey {
    static let defaultValue: Bool = true // Default to dark mode
}

// MARK: - Environment Key for Adaptive Colors
struct AdaptiveColorsKey: EnvironmentKey {
    static let defaultValue: SwissAdaptiveColors = SwissAdaptiveColors(isDarkMode: true)
}

extension EnvironmentValues {
    var isDarkMode: Bool {
        get { self[DarkModeKey.self] }
        set { self[DarkModeKey.self] = newValue }
    }

    var adaptiveColors: SwissAdaptiveColors {
        get { self[AdaptiveColorsKey.self] }
        set { self[AdaptiveColorsKey.self] = newValue }
    }
}

// MARK: - View Extension for Adaptive Colors
extension View {
    func adaptiveColors(_ isDarkMode: Bool) -> SwissAdaptiveColors {
        SwissAdaptiveColors(isDarkMode: isDarkMode)
    }

    /// Applies adaptive colors environment based on dark mode state
    func withAdaptiveColors(isDarkMode: Bool) -> some View {
        self.environment(\.adaptiveColors, SwissAdaptiveColors(isDarkMode: isDarkMode))
    }
}

// MARK: - Swiss Typography
struct SwissTypography {
    // Display - Large headlines
    static func display(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    // Headline - Section titles
    static func headline(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    // Title - Card titles
    static func title(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    // Body
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    // Mono Label - All caps, tracking
    static func monoLabel(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    // Stat number - Large numbers
    static func stat(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
}

// MARK: - View Modifiers
struct SwissLabelStyle: ViewModifier {
    let size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(SwissTypography.monoLabel(size))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundColor(SwissColors.gray400)
    }
}

extension View {
    func swissLabel(_ size: CGFloat = 11) -> some View {
        modifier(SwissLabelStyle(size: size))
    }
}

// MARK: - Swiss Card Component
struct SwissCard<Content: View>: View {
    @Environment(\.isDarkMode) var isDarkMode
    let content: Content
    var hasBorder: Bool = true
    var backgroundColor: Color? = nil

    init(hasBorder: Bool = true, backgroundColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.hasBorder = hasBorder
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        content
            .background(backgroundColor ?? colors.background)
            .overlay(
                Rectangle()
                    .stroke(hasBorder ? colors.borderSubtle : Color.clear, lineWidth: 1)
            )
    }
}

// MARK: - Swiss Section Header
struct SwissSectionHeader: View {
    @Environment(\.isDarkMode) var isDarkMode
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "View All"

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        HStack {
            Text(title)
                .font(SwissTypography.monoLabel(12))
                .textCase(.uppercase)
                .tracking(1.5)
                .fontWeight(.bold)
                .foregroundColor(colors.textPrimary)

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(SwissTypography.monoLabel(10))
                        .textCase(.uppercase)
                        .tracking(1)
                        .fontWeight(.bold)
                        .foregroundColor(colors.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(
                            Rectangle()
                                .stroke(colors.border, lineWidth: 1)
                        )
                }
            }
        }
    }
}

// MARK: - Swiss Stat Display
struct SwissStatDisplay: View {
    @Environment(\.isDarkMode) var isDarkMode
    let value: String
    let label: String
    var secondaryValue: String? = nil
    var size: StatSize = .large

    enum StatSize {
        case small, medium, large

        var valueSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 28
            case .large: return 56
            }
        }

        var labelSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 10
            case .large: return 10
            }
        }
    }

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(SwissTypography.stat(size.valueSize))
                    .tracking(-1)
                    .foregroundColor(colors.textPrimary)

                if let secondary = secondaryValue {
                    Text("/\(secondary)")
                        .font(SwissTypography.stat(size.valueSize * 0.5))
                        .foregroundColor(colors.textTertiary)
                }
            }

            Text(label)
                .font(SwissTypography.monoLabel(size.labelSize))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)
        }
    }
}

// MARK: - Swiss Badge
struct SwissBadge: View {
    let text: String
    var isWin: Bool = true

    var body: some View {
        Text(text)
            .font(SwissTypography.monoLabel(10))
            .textCase(.uppercase)
            .tracking(1)
            .fontWeight(.bold)
            .foregroundColor(SwissColors.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isWin ? SwissColors.green : SwissColors.red)
    }
}

// MARK: - Swiss Button Styles
struct SwissPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isDarkMode) var isDarkMode

    func makeBody(configuration: Configuration) -> some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        configuration.label
            .font(SwissTypography.monoLabel(11))
            .textCase(.uppercase)
            .tracking(1.5)
            .fontWeight(.bold)
            .foregroundColor(colors.primaryInverted)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(colors.primary)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .offset(
                x: configuration.isPressed ? 2 : 0,
                y: configuration.isPressed ? 2 : 0
            )
    }
}

struct SwissSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isDarkMode) var isDarkMode

    func makeBody(configuration: Configuration) -> some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        configuration.label
            .font(SwissTypography.monoLabel(11))
            .textCase(.uppercase)
            .tracking(1.5)
            .fontWeight(.bold)
            .foregroundColor(colors.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .overlay(
                Rectangle()
                    .stroke(colors.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct SwissGreenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SwissTypography.monoLabel(11))
            .textCase(.uppercase)
            .tracking(1.5)
            .fontWeight(.bold)
            .foregroundColor(SwissColors.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(SwissColors.green)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SwissGreenOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SwissTypography.monoLabel(11))
            .textCase(.uppercase)
            .tracking(1.5)
            .fontWeight(.bold)
            .foregroundColor(SwissColors.green)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .overlay(
                Rectangle()
                    .stroke(SwissColors.green, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Swiss Tab Bar
struct SwissTabBar: View {
    @Environment(\.isDarkMode) var isDarkMode
    @Binding var selectedTab: Int
    let items: [(icon: String, label: String)]

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button(action: { selectedTab = index }) {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20))

                        Text(item.label)
                            .font(SwissTypography.monoLabel(9))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    .foregroundColor(selectedTab == index ? SwissColors.green : colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == index ?
                        SwissColors.greenLight :
                        Color.clear
                    )
                }
            }
        }
        .background(colors.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(colors.borderSubtle),
            alignment: .top
        )
    }
}

// MARK: - Swiss Sport Filter Pills
struct SwissSportFilterPills: View {
    @Binding var selectedSport: SportFilter

    var body: some View {
        HStack(spacing: 8) {
            SwissFilterPill(title: "All Sports", isSelected: selectedSport == .all) {
                selectedSport = .all
            }

            SwissFilterPill(icon: "🎾", title: "Tennis", isSelected: selectedSport == .tennis) {
                selectedSport = .tennis
            }

            SwissFilterPill(icon: "🥒", title: "Pickleball", isSelected: selectedSport == .pickleball) {
                selectedSport = .pickleball
            }

            SwissFilterPill(icon: "🏓", title: "Padel", isSelected: selectedSport == .padel) {
                selectedSport = .padel
            }
        }
    }
}

struct SwissFilterPill: View {
    @Environment(\.isDarkMode) var isDarkMode
    var icon: String? = nil
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Text(icon)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(SwissTypography.monoLabel(10))
                    .textCase(.uppercase)
                    .tracking(1)
                    .fontWeight(.bold)
            }
            .foregroundColor(isSelected ? SwissColors.white : colors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12) // Increased for 44pt minimum
            .frame(minHeight: 44) // Ensure minimum touch target
            .background(
                isSelected ? SwissColors.green : Color.clear
            )
            .overlay(
                Rectangle()
                    .stroke(isSelected ? SwissColors.green : colors.borderSubtle, lineWidth: isSelected ? 2 : 1)
            )
        }
        .accessibilityLabel("\(title) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Swiss Activity Row
struct SwissActivityRow: View {
    @Environment(\.isDarkMode) var isDarkMode
    let game: WatchGameRecord
    var onTap: (() -> Void)? = nil

    private var accessibilityDescription: String {
        let result = game.winner == "You" ? "won" : "lost"
        return "\(game.sportType) \(game.gameType), \(result) \(game.scoreDisplay), \(game.date.timeAgoDisplay()), duration \(game.elapsedTimeDisplay)"
    }

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Sport emoji
                Text(game.sportEmoji)
                    .font(.system(size: 24))
                    .accessibilityHidden(true)

                // Game info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 12) {
                        Text("\(game.sportType) \(game.gameType)")
                            .font(.system(size: 18, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(colors.textPrimary)

                        Text(game.date.timeAgoDisplay())
                            .font(SwissTypography.monoLabel(10))
                            .textCase(.uppercase)
                            .foregroundColor(colors.textSecondary)
                    }

                    Text("Match Duration: \(game.elapsedTimeDisplay)")
                        .font(SwissTypography.monoLabel(11))
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                // Score and result
                VStack(alignment: .trailing, spacing: 4) {
                    Text(game.scoreDisplay)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(colors.textPrimary)

                    if let winner = game.winner {
                        SwissBadge(
                            text: winner == "You" ? "WIN" : "LOSS",
                            isWin: winner == "You"
                        )
                    }
                }
            }
            .padding(.vertical, 16)
            .frame(minHeight: 60) // Ensure minimum 44pt touch target
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view game details")
    }
}

// MARK: - Swiss Progress Bar
struct SwissProgressBar: View {
    let value: Double
    var height: CGFloat = 4
    var foregroundColor: Color = SwissColors.black
    var backgroundColor: Color = SwissColors.gray100

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(backgroundColor)
                    .frame(height: height)

                Rectangle()
                    .fill(foregroundColor)
                    .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Swiss Icon Button
struct SwissIconButton: View {
    @Environment(\.isDarkMode) var isDarkMode
    let icon: String
    var size: CGFloat = 14
    var accessibilityLabel: String = ""
    let action: () -> Void

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(colors.primary)
                .frame(width: 44, height: 44) // Apple HIG minimum
                .contentShape(Rectangle()) // Ensure full area is tappable
        }
        .accessibilityLabel(accessibilityLabel.isEmpty ? icon : accessibilityLabel)
    }
}

// MARK: - Swiss Floating Action Button
struct SwissFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(SwissColors.white)
                .frame(width: 56, height: 56)
                .background(SwissColors.green)
                .shadow(color: SwissColors.green.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Date Extension for Time Ago
extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)

        if let day = components.day, day > 0 {
            return "\(day)d ago"
        }
        if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        }
        if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        }
        return "Just now"
    }
}

// MARK: - Shared Time Formatter
struct TimeFormatter {
    /// Format TimeInterval to readable string (e.g., "1h 30m" or "45m")
    static func format(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Format TimeInterval to short string (e.g., "1:30" or "0:45")
    static func formatShort(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }

    /// Format TimeInterval for accessibility (e.g., "1 hour 30 minutes")
    static func formatAccessible(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 {
            parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "0 minutes" : parts.joined(separator: " ")
    }
}

// MARK: - Reusable Stat Block with Icon
struct SwissStatBlock: View {
    @Environment(\.isDarkMode) var isDarkMode
    let icon: String
    let value: String
    let label: String
    var iconColor: Color? = nil

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor ?? colors.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colors.textPrimary)
                Text(label)
                    .font(SwissTypography.monoLabel(9))
                    .foregroundColor(colors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Reusable Large Stat Display
struct SwissLargeStat: View {
    @Environment(\.isDarkMode) var isDarkMode
    let value: String
    let label: String
    var secondaryValue: String? = nil
    var valueColor: Color? = nil

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 56, weight: .bold))
                    .tracking(-2)
                    .foregroundColor(valueColor ?? colors.textPrimary)
                if let secondary = secondaryValue {
                    Text("/\(secondary)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(colors.textTertiary)
                }
            }
            Text(label)
                .font(SwissTypography.monoLabel(10))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(secondaryValue != nil ? " of \(secondaryValue!)" : "")")
    }
}

// MARK: - Swiss Collapsible Section
struct SwissCollapsibleSection<Content: View>: View {
    @Environment(\.isDarkMode) var isDarkMode
    let title: String
    @State private var isExpanded: Bool = false
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let colors = SwissAdaptiveColors(isDarkMode: isDarkMode)
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack {
                    Text(title)
                        .font(SwissTypography.monoLabel(12))
                        .textCase(.uppercase)
                        .tracking(1)
                        .fontWeight(.bold)
                        .foregroundColor(colors.textSecondary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(colors.textTertiary)
                }
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.bottom, 16)
            }

            Rectangle()
                .fill(colors.borderSubtle)
                .frame(height: 1)
        }
    }
}
