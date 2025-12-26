//
//  SwissAnimations.swift
//  PointiOS
//
//  Swiss Minimalist Animation System
//  Subtle, purposeful animations that enhance UX
//

import SwiftUI

// MARK: - Animation Constants
struct SwissAnimation {
    // Timing (in seconds)
    static let quickDuration: Double = 0.15
    static let standardDuration: Double = 0.25
    static let smoothDuration: Double = 0.35
    static let slowDuration: Double = 0.5

    // Springs
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.8)

    // Easing
    static let easeOut = Animation.easeOut(duration: standardDuration)
    static let easeIn = Animation.easeIn(duration: standardDuration)
    static let smooth = Animation.easeInOut(duration: smoothDuration)
}

// MARK: - Staggered Load Animation
struct StaggeredAppear: ViewModifier {
    let index: Int
    let total: Int
    @State private var isVisible = false

    private var delay: Double {
        Double(index) * 0.05
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(SwissAnimation.gentle.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Slide Up Appear
struct SlideUpAppear: ViewModifier {
    @State private var isVisible = false
    var delay: Double = 0
    var distance: CGFloat = 30

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : distance)
            .onAppear {
                withAnimation(SwissAnimation.gentle.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Fade In Appear
struct FadeInAppear: ViewModifier {
    @State private var isVisible = false
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: SwissAnimation.smoothDuration).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Scale Appear
struct ScaleAppear: ViewModifier {
    @State private var isVisible = false
    var delay: Double = 0
    var fromScale: CGFloat = 0.8

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : fromScale)
            .onAppear {
                withAnimation(SwissAnimation.bouncy.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Number Counter Animation
struct AnimatedNumber: View {
    let value: Int
    let duration: Double

    @State private var displayValue: Int = 0

    init(_ value: Int, duration: Double = 0.8) {
        self.value = value
        self.duration = duration
    }

    var body: some View {
        Text("\(displayValue)")
            .onAppear {
                animateValue()
            }
            .onChange(of: value) { _, _ in
                animateValue()
            }
    }

    private func animateValue() {
        let steps = 20
        let stepDuration = duration / Double(steps)
        let increment = Double(value - displayValue) / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                if step == steps {
                    displayValue = value
                } else {
                    displayValue = Int(Double(displayValue) + increment)
                }
            }
        }
    }
}

// MARK: - Press Effect (Scale + Haptic)
struct PressEffect: ViewModifier {
    @State private var isPressed = false
    var scale: CGFloat = 0.96
    var enableHaptic: Bool = true

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1)
            .animation(SwissAnimation.snappy, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            if enableHaptic {
                                HapticManager.shared.impact(.light)
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - Bounce Press Effect
struct BouncePressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.92 : 1)
            .animation(SwissAnimation.bouncy, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.impact(.medium)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - Shimmer Loading Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            SwissColors.white.opacity(0.5),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Pulse Effect
struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    var minScale: CGFloat = 0.95
    var maxScale: CGFloat = 1.05

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Progress Bar Animation
struct AnimatedProgressBar: View {
    let value: Double
    var height: CGFloat = 4
    var foregroundColor: Color = SwissColors.green
    var backgroundColor: Color = SwissColors.gray100
    var delay: Double = 0

    @State private var animatedValue: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(backgroundColor)
                    .frame(height: height)

                Rectangle()
                    .fill(foregroundColor)
                    .frame(width: geometry.size.width * CGFloat(animatedValue), height: height)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(delay)) {
                animatedValue = min(max(value, 0), 1)
            }
        }
    }
}

// MARK: - Chart Bar Animation
struct AnimatedChartBar: View {
    let height: CGFloat
    let maxHeight: CGFloat
    let color: Color
    let delay: Double

    @State private var animatedHeight: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: animatedHeight)
            .onAppear {
                withAnimation(SwissAnimation.bouncy.delay(delay)) {
                    animatedHeight = height
                }
            }
    }
}

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - View Extensions
extension View {
    func staggeredAppear(index: Int, total: Int) -> some View {
        modifier(StaggeredAppear(index: index, total: total))
    }

    func slideUpAppear(delay: Double = 0, distance: CGFloat = 30) -> some View {
        modifier(SlideUpAppear(delay: delay, distance: distance))
    }

    func fadeInAppear(delay: Double = 0) -> some View {
        modifier(FadeInAppear(delay: delay))
    }

    func scaleAppear(delay: Double = 0, from: CGFloat = 0.8) -> some View {
        modifier(ScaleAppear(delay: delay, fromScale: from))
    }

    func pressEffect(scale: CGFloat = 0.96, haptic: Bool = true) -> some View {
        modifier(PressEffect(scale: scale, enableHaptic: haptic))
    }

    func bouncePress() -> some View {
        modifier(BouncePressEffect())
    }

    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }

    func pulse(min: CGFloat = 0.95, max: CGFloat = 1.05) -> some View {
        modifier(PulseEffect(minScale: min, maxScale: max))
    }
}

// MARK: - Animated Counter Text
struct AnimatedCounterText: View {
    let value: Int
    let font: Font
    let color: Color

    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: 0.3)) {
                    displayValue = newValue
                }
            }
    }
}

// MARK: - Success Checkmark Animation
struct AnimatedCheckmark: View {
    @State private var isAnimating = false
    var size: CGFloat = 60
    var color: Color = SwissColors.green

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: isAnimating ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            Image(systemName: "checkmark")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(color)
                .scaleEffect(isAnimating ? 1 : 0)
                .opacity(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
            HapticManager.shared.notification(.success)
        }
    }
}

// MARK: - Win/Loss Badge Animation
struct AnimatedBadge: View {
    let isWin: Bool
    @State private var isVisible = false

    var body: some View {
        Text(isWin ? "WIN" : "LOSS")
            .font(SwissTypography.monoLabel(10))
            .textCase(.uppercase)
            .tracking(1)
            .fontWeight(.bold)
            .foregroundColor(SwissColors.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isWin ? SwissColors.green : SwissColors.red)
            .scaleEffect(isVisible ? 1 : 0)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(SwissAnimation.bouncy.delay(0.2)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Floating Action Button with Animation
struct AnimatedFAB: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var isVisible = false

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(SwissColors.white)
                .frame(width: 56, height: 56)
                .background(SwissColors.green)
                .shadow(color: SwissColors.green.opacity(0.4), radius: 12, x: 0, y: 6)
                .scaleEffect(isPressed ? 0.9 : 1)
                .rotationEffect(.degrees(isPressed ? 90 : 0))
        }
        .scaleEffect(isVisible ? 1 : 0)
        .opacity(isVisible ? 1 : 0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(SwissAnimation.snappy, value: isPressed)
        .onAppear {
            withAnimation(SwissAnimation.bouncy.delay(0.5)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Score Display Animation
struct AnimatedScoreDisplay: View {
    let player1Score: Int
    let player2Score: Int
    let isWin: Bool

    @State private var player1Visible = false
    @State private var player2Visible = false
    @State private var dividerVisible = false

    var body: some View {
        HStack(spacing: 48) {
            // Player 1 Score
            VStack(spacing: 8) {
                Text("You")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(SwissColors.white.opacity(0.6))

                Text("\(player1Score)")
                    .font(.system(size: 64, weight: .bold))
                    .tracking(-3)
                    .foregroundColor(SwissColors.white)
            }
            .opacity(player1Visible ? 1 : 0)
            .offset(x: player1Visible ? 0 : -30)

            // Divider
            Rectangle()
                .fill(SwissColors.white.opacity(0.2))
                .frame(width: 1, height: 64)
                .rotationEffect(.degrees(12))
                .scaleEffect(y: dividerVisible ? 1 : 0)
                .opacity(dividerVisible ? 1 : 0)

            // Player 2 Score
            VStack(spacing: 8) {
                Text("Opponent")
                    .font(SwissTypography.monoLabel(11))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundColor(SwissColors.white.opacity(0.6))

                Text("\(player2Score)")
                    .font(.system(size: 64, weight: .bold))
                    .tracking(-3)
                    .foregroundColor(SwissColors.white.opacity(0.4))
            }
            .opacity(player2Visible ? 1 : 0)
            .offset(x: player2Visible ? 0 : 30)
        }
        .onAppear {
            withAnimation(SwissAnimation.gentle.delay(0.1)) {
                player1Visible = true
            }
            withAnimation(SwissAnimation.gentle.delay(0.2)) {
                dividerVisible = true
            }
            withAnimation(SwissAnimation.gentle.delay(0.3)) {
                player2Visible = true
            }
        }
    }
}
