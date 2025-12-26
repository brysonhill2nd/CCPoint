//
//  WatchDesignSystem.swift
//  PointiOS Watch App
//
//  Swiss Minimalist Design System for Apple Watch
//  Aligned with iOS SwissDesignSystem
//

import SwiftUI

// MARK: - Watch Colors
struct WatchColors {
    // Primary brand color - matches iOS SwissColors.green
    static let green = Color(red: 0.420, green: 0.620, blue: 0.243) // #6B9E3E
    static let greenLight = green.opacity(0.3)
    static let greenMuted = green.opacity(0.6)

    // Semantic colors
    static let win = green
    static let loss = Color(red: 0.725, green: 0.110, blue: 0.110) // #B91C1C - matches iOS
    static let warning = Color(red: 0.945, green: 0.769, blue: 0.059) // #F1C40F - yellow
    static let caution = Color.orange

    // Background (Watch is always dark)
    static let background = Color.black
    static let surface = Color(white: 0.1) // Slightly lighter for cards
    static let surfaceElevated = Color(white: 0.15)

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.7)
    static let textTertiary = Color(white: 0.5)
    static let textMuted = Color(white: 0.35)

    // Borders
    static let border = Color.white
    static let borderSubtle = Color.white.opacity(0.2)
    static let borderMuted = Color.white.opacity(0.1)

    // Player colors (for score display)
    static let player1 = green  // You/Player 1 - brand green
    static let player2 = Color(white: 0.6)  // Opponent - neutral gray

    // Service indicator
    static let serviceActive = green
    static let serviceInactive = Color(white: 0.3)

    // Interactive states
    static let buttonPrimary = green
    static let buttonSecondary = Color(white: 0.2)
    static let buttonDestructive = loss
    static let buttonDisabled = Color(white: 0.3)
}

// MARK: - Watch Typography
struct WatchTypography {
    // Score displays - large, bold, rounded for readability
    static func scoreXL() -> Font {
        .system(size: 64, weight: .bold, design: .rounded)
    }

    static func scoreLarge() -> Font {
        .system(size: 36, weight: .bold, design: .rounded)
    }

    static func scoreMedium() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }

    static func scoreSmall() -> Font {
        .system(size: 20, weight: .bold, design: .rounded)
    }

    // Labels - monospaced for Swiss style
    static func monoLabel(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    // Headlines
    static func headline() -> Font {
        .system(size: 14, weight: .semibold)
    }

    static func subheadline() -> Font {
        .system(size: 12, weight: .medium)
    }

    // Body text
    static func body() -> Font {
        .system(size: 13, weight: .regular)
    }

    static func caption() -> Font {
        .system(size: 10, weight: .medium)
    }

    // Button text
    static func button() -> Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Watch Card Component
struct WatchCard<Content: View>: View {
    let content: Content
    var backgroundColor: Color = WatchColors.surface
    var cornerRadius: CGFloat = 12
    var hasBorder: Bool = false

    init(
        backgroundColor: Color = WatchColors.surface,
        cornerRadius: CGFloat = 12,
        hasBorder: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.hasBorder = hasBorder
        self.content = content()
    }

    var body: some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(hasBorder ? WatchColors.borderSubtle : Color.clear, lineWidth: 1)
            )
    }
}

// MARK: - Watch Score Box
struct WatchScoreBox: View {
    let score: String
    var isServing: Bool = false
    var isHighlighted: Bool = false
    var size: ScoreSize = .large

    enum ScoreSize {
        case small, medium, large, extraLarge

        var font: Font {
            switch self {
            case .small: return WatchTypography.scoreSmall()
            case .medium: return WatchTypography.scoreMedium()
            case .large: return WatchTypography.scoreLarge()
            case .extraLarge: return WatchTypography.scoreXL()
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            case .medium: return EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
            case .large: return EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            case .extraLarge: return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            }
        }
    }

    var body: some View {
        Text(score)
            .font(size.font)
            .foregroundColor(WatchColors.textPrimary)
            .padding(size.padding)
            .frame(maxWidth: .infinity)
            .background(
                isHighlighted ? WatchColors.greenLight : WatchColors.surface
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isServing ? WatchColors.green : WatchColors.borderSubtle, lineWidth: isServing ? 2 : 1)
            )
    }
}

// MARK: - Watch Service Dots
struct WatchServiceDots: View {
    let count: Int
    let filled: Int
    var dotSize: CGFloat = 8

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index < filled ? WatchColors.serviceActive : WatchColors.serviceInactive)
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
}

// MARK: - Watch Badge
struct WatchBadge: View {
    let text: String
    var isWin: Bool = true
    var style: BadgeStyle = .filled

    enum BadgeStyle {
        case filled, outline
    }

    var body: some View {
        Text(text)
            .font(WatchTypography.monoLabel(9))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundColor(style == .filled ? (isWin ? .black : .white) : (isWin ? WatchColors.win : WatchColors.loss))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                style == .filled ?
                (isWin ? WatchColors.win : WatchColors.loss) :
                Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                style == .outline ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isWin ? WatchColors.win : WatchColors.loss, lineWidth: 1) :
                nil
            )
    }
}

// MARK: - Watch Banner
struct WatchBanner: View {
    let text: String
    var color: Color = WatchColors.warning
    var textColor: Color = .black

    var body: some View {
        Text(text)
            .font(WatchTypography.monoLabel(9))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Watch Icon Button
struct WatchIconButton: View {
    let icon: String
    var color: Color = WatchColors.textSecondary
    var backgroundColor: Color = WatchColors.buttonSecondary
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Watch Settings Row
struct WatchSettingsRow: View {
    let title: String
    let value: String
    var icon: String? = nil

    var body: some View {
        WatchCard {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(WatchColors.green)
                        .frame(width: 24)
                }

                Text(title)
                    .font(WatchTypography.subheadline())
                    .foregroundColor(WatchColors.textSecondary)

                Spacer()

                Text(value)
                    .font(WatchTypography.headline())
                    .foregroundColor(WatchColors.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Watch History Row
struct WatchHistoryRow: View {
    let sportEmoji: String
    let gameType: String
    let score: String
    let result: String
    let duration: String
    let isWin: Bool

    var body: some View {
        WatchCard(hasBorder: true) {
            HStack(spacing: 10) {
                // Sport indicator
                Text(sportEmoji)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text(gameType)
                        .font(WatchTypography.caption())
                        .foregroundColor(WatchColors.textTertiary)
                        .textCase(.uppercase)

                    Text(score)
                        .font(WatchTypography.headline())
                        .foregroundColor(WatchColors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    WatchBadge(text: result, isWin: isWin)

                    Text(duration)
                        .font(WatchTypography.caption())
                        .foregroundColor(WatchColors.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Watch Primary Button Style
struct WatchPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WatchTypography.button())
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundColor(isEnabled ? .black : WatchColors.textTertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isEnabled ? WatchColors.green : WatchColors.buttonDisabled)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Watch Secondary Button Style
struct WatchSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WatchTypography.button())
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundColor(WatchColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(WatchColors.buttonSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(WatchColors.borderSubtle, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Watch Destructive Button Style
struct WatchDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WatchTypography.button())
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(WatchColors.buttonDestructive)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - View Extensions
extension View {
    func watchCard(
        backgroundColor: Color = WatchColors.surface,
        cornerRadius: CGFloat = 12,
        hasBorder: Bool = false
    ) -> some View {
        self
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(hasBorder ? WatchColors.borderSubtle : Color.clear, lineWidth: 1)
            )
    }
}
