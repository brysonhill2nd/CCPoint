// SessionShareView.swift
import SwiftUI
import UIKit
import AVFoundation

struct SessionShareView: View {
    let sessionData: SessionSummary
    @Environment(\.dismiss) var dismiss
    @State private var selectedStyle: ShareStyle = .receipt
    @State private var shareImage: UIImage? = nil
    @State private var showingShareSheet = false
    @State private var showLocation = true

    enum ShareStyle: String, CaseIterable {
        case receipt = "Receipt"
        case minimal = "Minimal"
        case green = "Green"
        case dark = "Dark"
        case transparent = "Camera"
        case storyOverlay = "Story"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Swiss Header
            HStack {
                Text("Share Session")
                    .font(SwissTypography.monoLabel(12))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .fontWeight(.bold)
                    .foregroundColor(SwissColors.black)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24))
                        .foregroundColor(SwissColors.black)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Rectangle()
                .fill(SwissColors.gray)
                .frame(height: 1)

            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    sharePreview
                        .padding(.top, 24)

                    // Style Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Style")
                            .font(SwissTypography.monoLabel(10))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(SwissColors.gray400)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ShareStyle.allCases, id: \.self) { style in
                                    SwissStyleButton(
                                        label: style.rawValue,
                                        isSelected: selectedStyle == style,
                                        action: { selectedStyle = style }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Location Toggle
                    Button(action: { showLocation.toggle() }) {
                        HStack {
                            Image(systemName: showLocation ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundColor(showLocation ? SwissColors.black : SwissColors.gray400)
                            Text("Show Location")
                                .font(SwissTypography.monoLabel(11))
                                .foregroundColor(SwissColors.black)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                    .buttonStyle(.plain)

                    // Share Button
                    Button(action: generateAndShare) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                            Text("Share")
                        }
                    }
                    .buttonStyle(SwissPrimaryButtonStyle())
                    .padding(.horizontal, 24)

                    // Quick Share Options
                    VStack(spacing: 16) {
                        Text("Quick Share")
                            .font(SwissTypography.monoLabel(10))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(SwissColors.gray400)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 16) {
                            SwissQuickShareButton(
                                icon: "camera.fill",
                                label: "Stories",
                                action: shareToInstagramStories
                            )
                            SwissQuickShareButton(icon: "message.fill", label: "Message")
                            SwissQuickShareButton(icon: "link", label: "Copy Link")
                            SwissQuickShareButton(icon: "doc.on.doc", label: "Copy")
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 48)
            }
        }
        .background(SwissColors.white)
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Preview based on style
    @ViewBuilder
    private var sharePreview: some View {
        switch selectedStyle {
        case .receipt:
            SwissSessionReceiptPreview(sessionData: sessionData, showLocation: showLocation)
                .padding(.horizontal, 24)
        case .minimal:
            SwissMinimalCard(sessionData: sessionData, showLocation: showLocation)
                .padding(.horizontal, 24)
        case .green:
            StravaStyleCard(sessionData: sessionData, showLocation: showLocation)
                .padding(.horizontal, 24)
        case .dark:
            SwissDarkCard(sessionData: sessionData, showLocation: showLocation)
                .padding(.horizontal, 24)
        case .transparent:
            ZStack {
                CheckeredPattern()
                    .frame(height: 300)
                    .cornerRadius(12)
                TransparentOverlayCard(sessionData: sessionData, showLocation: showLocation)
            }
            .padding(.horizontal, 24)
        case .storyOverlay:
            ZStack {
                CheckeredPattern()
                    .frame(height: 400)
                    .cornerRadius(12)
                StoryOverlayCard(sessionData: sessionData, showLocation: showLocation)
            }
            .padding(.horizontal, 24)
        }
    }

    private func generateAndShare() {
        guard let image = renderImage(for: selectedStyle) else { return }
        shareImage = image
        showingShareSheet = true
    }

    private func shareToInstagramStories() {
        guard let url = URL(string: "instagram-stories://share") else { return }
        guard UIApplication.shared.canOpenURL(url) else { return }

        guard let image = renderImage(for: selectedStyle),
              let pngData = image.pngData() else {
            return
        }

        let pasteboardKey = selectedStyle == .storyOverlay
            ? "com.instagram.sharedSticker.backgroundImage"
            : "com.instagram.sharedSticker.stickerImage"

        UIPasteboard.general.setItems(
            [[pasteboardKey: pngData]],
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )

        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func renderImage(for style: ShareStyle) -> UIImage? {
        let content = exportView(for: style)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        renderer.isOpaque = false
        return renderer.uiImage
    }

    private func exportView(for style: ShareStyle) -> AnyView {
        switch style {
        case .receipt:
            return AnyView(SwissSessionReceiptExport(sessionData: sessionData, showLocation: showLocation))
        case .minimal:
            return AnyView(SwissMinimalExport(sessionData: sessionData, showLocation: showLocation))
        case .green:
            return AnyView(StravaStyleExport(sessionData: sessionData, showLocation: showLocation))
        case .dark:
            return AnyView(SwissDarkExport(sessionData: sessionData, showLocation: showLocation))
        case .transparent:
            return AnyView(TransparentExport(sessionData: sessionData, showLocation: showLocation))
        case .storyOverlay:
            return AnyView(StoryOverlayExport(sessionData: sessionData, showLocation: showLocation))
        }
    }
}

// MARK: - Swiss Style Button
struct SwissStyleButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SwissTypography.monoLabel(11))
                .textCase(.uppercase)
                .tracking(1)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? SwissColors.white : SwissColors.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? SwissColors.black : SwissColors.white)
                .overlay(
                    Rectangle()
                        .stroke(SwissColors.black, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swiss Receipt Style (Preview)
struct SwissSessionReceiptPreview: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Torn edge top
            TornEdge()
                .fill(SwissColors.gray50)
                .frame(height: 8)

            ZStack {
                // Background with faint trophy
                SwissColors.gray50

                // Faint Lucide Trophy watermark
                if let trophyIcon = LucideIcon.named("trophy") {
                    Image(icon: trophyIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .foregroundColor(SwissColors.green.opacity(0.08))
                        .offset(y: 20)
                }

                // Content
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            PointWordmark(size: 22, textColor: SwissColors.black)
                            Text("Session Record")
                                .font(SwissTypography.monoLabel(9))
                                .textCase(.uppercase)
                                .tracking(1)
                                .foregroundColor(SwissColors.gray400)
                        }
                        Spacer()
                        Text(sessionData.gamesWon > (sessionData.gamesPlayed - sessionData.gamesWon) ? "W" : "L")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(sessionData.gamesWon > (sessionData.gamesPlayed - sessionData.gamesWon) ? SwissColors.green : SwissColors.red)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Dashed divider
                    DashedDivider()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .fill(SwissColors.gray300)
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    // Score
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("WON")
                                .font(SwissTypography.monoLabel(8))
                                .foregroundColor(SwissColors.gray400)
                            Text("\(sessionData.gamesWon)")
                                .font(.system(size: 40, weight: .bold))
                                .tracking(-2)
                                .foregroundColor(SwissColors.green)
                        }
                        Text(":")
                            .font(.system(size: 28))
                            .foregroundColor(SwissColors.gray300)
                        VStack(spacing: 2) {
                            Text("LOST")
                                .font(SwissTypography.monoLabel(8))
                                .foregroundColor(SwissColors.gray400)
                            Text("\(sessionData.gamesPlayed - sessionData.gamesWon)")
                                .font(.system(size: 40, weight: .bold))
                                .tracking(-2)
                                .foregroundColor(SwissColors.gray400)
                        }
                    }
                    .padding(.vertical, 8)

                    DashedDivider()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .fill(SwissColors.gray300)
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    // Stats row
                    HStack(spacing: 0) {
                        ReceiptStatBlock(value: formatTime(sessionData.totalTime), label: "Time")
                        ReceiptStatBlock(value: "\(Int(sessionData.calories))", label: "Cal")
                        ReceiptStatBlock(value: "\(Int(sessionData.avgHeartRate))", label: "BPM")
                    }
                    .padding(.horizontal, 12)

                    if showLocation {
                        DashedDivider()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .fill(SwissColors.gray300)
                            .frame(height: 1)
                            .padding(.horizontal, 12)

                        HStack(spacing: 6) {
                            Image(systemName: "mappin")
                                .font(.system(size: 12))
                                .foregroundColor(SwissColors.gray400)
                            Text(sessionData.location)
                                .font(SwissTypography.monoLabel(10))
                                .foregroundColor(SwissColors.black)
                        }
                        .padding(.vertical, 8)
                    }

                    // Footer
                    VStack(spacing: 6) {
                        Text("pointapp.app")
                            .font(SwissTypography.monoLabel(9))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundColor(SwissColors.gray400)

                        // Mini barcode
                        HStack(spacing: 1) {
                            ForEach(0..<20, id: \.self) { _ in
                                Rectangle()
                                    .fill(SwissColors.black)
                                    .frame(width: CGFloat.random(in: 1...2), height: 20)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }

            // Torn edge bottom
            TornEdge()
                .fill(SwissColors.gray50)
                .frame(height: 8)
                .rotationEffect(.degrees(180))
        }
        .overlay(
            Rectangle()
                .stroke(SwissColors.gray200, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Swiss Minimal Card
struct SwissMinimalCard: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        ZStack {
            // Background
            SwissColors.white

            // Faint Lucide Trophy watermark
            if let trophyIcon = LucideIcon.named("trophy") {
                Image(icon: trophyIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .foregroundColor(SwissColors.green.opacity(0.06))
            }

            // Content
            VStack(spacing: 24) {
                // Big score
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(sessionData.gamesWon)")
                        .font(.system(size: 72, weight: .bold))
                        .tracking(-3)
                        .foregroundColor(SwissColors.green)
                    Text("-")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(SwissColors.gray300)
                    Text("\(sessionData.gamesPlayed - sessionData.gamesWon)")
                        .font(.system(size: 72, weight: .bold))
                        .tracking(-3)
                        .foregroundColor(SwissColors.gray400)
                }

                // Stats
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("Duration")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(SwissColors.gray400)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("Calories")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(SwissColors.gray400)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("BPM")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(SwissColors.gray400)
                    }
                }

                if showLocation {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(10))
                    }
                    .foregroundColor(SwissColors.gray400)
                }

                // Logo
                PointWordmark(size: 20, textColor: SwissColors.black)
                .opacity(0.6)
            }
            .padding(32)
        }
        .overlay(
            Rectangle()
                .stroke(SwissColors.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Strava Style Card (Green gradient with trophy)
struct StravaStyleCard: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        ZStack {
            // Green gradient background
            LinearGradient(
                colors: [
                    SwissColors.green,
                    SwissColors.green.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Faint trophy watermark
            if let trophyIcon = LucideIcon.named("trophy") {
                Image(icon: trophyIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .foregroundColor(.white.opacity(0.1))
                    .offset(x: 60, y: 40)
            }

            // Content
            VStack(spacing: 20) {
                // Logo
                PointWordmark(size: 24, textColor: .white)

                // Big record
                Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                    .font(.system(size: 56, weight: .bold))
                    .tracking(-2)
                    .foregroundColor(.white)

                Text("Session Record")
                    .font(SwissTypography.monoLabel(10))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.7))

                // Stats row
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Time")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Cal")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                if showLocation {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(10))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(32)
        }
        .cornerRadius(16)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Swiss Dark Card
struct SwissDarkCard: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        ZStack {
            // Background
            Color.black

            // Faint trophy watermark
            if let trophyIcon = LucideIcon.named("trophy") {
                Image(icon: trophyIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .foregroundColor(SwissColors.green.opacity(0.08))
            }

            // Content
            VStack(spacing: 24) {
                // Logo
                PointWordmark(size: 22, textColor: .white)
                .opacity(0.8)

                // Score
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(sessionData.gamesWon)")
                        .font(.system(size: 64, weight: .bold))
                        .tracking(-3)
                        .foregroundColor(SwissColors.green)
                    Text("-")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text("\(sessionData.gamesPlayed - sessionData.gamesWon)")
                        .font(.system(size: 64, weight: .bold))
                        .tracking(-3)
                        .foregroundColor(.white.opacity(0.5))
                }

                // Stats
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Duration")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Calories")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(SwissTypography.monoLabel(9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                if showLocation {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(10))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(32)
        }
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Transparent Overlay Card
struct TransparentOverlayCard: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        ZStack {
            // Faint trophy watermark
            if let trophyIcon = LucideIcon.named("trophy") {
                Image(icon: trophyIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.white.opacity(0.08))
            }

            VStack(spacing: 16) {
                PointWordmark(size: 20, textColor: .white)

                Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                    .font(.system(size: 48, weight: .bold))
                    .tracking(-2)
                    .foregroundColor(.white)

                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Time")
                            .font(SwissTypography.monoLabel(8))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    VStack(spacing: 2) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Cal")
                            .font(SwissTypography.monoLabel(8))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    VStack(spacing: 2) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(SwissTypography.monoLabel(8))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                if showLocation {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(9))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SwissColors.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Story Overlay Card (for Instagram Stories - Strava-style)
struct StoryOverlayCard: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Bottom overlay section - Strava style
            VStack(spacing: 16) {
                // Logo and app name
                PointWordmark(size: 18, textColor: .white)

                // Main score - big and bold
                Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                    .font(.system(size: 56, weight: .black))
                    .tracking(-2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                // Sport type badge
                Text(sessionData.sport.uppercased())
                    .font(SwissTypography.monoLabel(10))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.15))
                    )

                // Stats row
                HStack(spacing: 24) {
                    StoryStatItem(value: formatTime(sessionData.totalTime), label: "TIME")

                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 1, height: 32)

                    StoryStatItem(value: "\(Int(sessionData.calories))", label: "CAL")

                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 1, height: 32)

                    StoryStatItem(value: "\(Int(sessionData.avgHeartRate))", label: "BPM")
                }
                .padding(.top, 8)

                // Location if enabled
                if showLocation {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(10))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: 400)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StoryStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(SwissTypography.monoLabel(8))
                .tracking(1)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Export Views (Full Resolution)

struct SwissSessionReceiptExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        SwissSessionReceiptPreview(sessionData: sessionData, showLocation: showLocation)
            .frame(width: 400)
            .padding(40)
            .background(SwissColors.white)
    }
}

struct SwissMinimalExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        SwissMinimalCard(sessionData: sessionData, showLocation: showLocation)
            .frame(width: 400)
            .padding(40)
            .background(SwissColors.white)
    }
}

struct StravaStyleExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        StravaStyleCard(sessionData: sessionData, showLocation: showLocation)
            .frame(width: 400)
            .padding(40)
            .background(Color.clear)
    }
}

struct SwissDarkExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        SwissDarkCard(sessionData: sessionData, showLocation: showLocation)
            .frame(width: 400)
            .padding(40)
            .background(Color.black)
    }
}

struct TransparentExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        TransparentOverlayCard(sessionData: sessionData, showLocation: showLocation)
            .frame(width: 400)
            .padding(40)
            .background(Color.clear)
    }
}

// Story overlay export - Instagram Story dimensions (1080x1920)
struct StoryOverlayExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Bottom overlay - matches Strava's style
            VStack(spacing: 20) {
                // Logo
                PointWordmark(size: 24, textColor: .white)

                // Score
                Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                    .font(.system(size: 72, weight: .black))
                    .tracking(-3)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)

                // Sport badge
                Text(sessionData.sport.uppercased())
                    .font(SwissTypography.monoLabel(14))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.2))
                    )

                // Stats
                HStack(spacing: 40) {
                    VStack(spacing: 6) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("TIME")
                            .font(SwissTypography.monoLabel(11))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 1, height: 44)

                    VStack(spacing: 6) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("CAL")
                            .font(SwissTypography.monoLabel(11))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 1, height: 44)

                    VStack(spacing: 6) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(SwissTypography.monoLabel(11))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.top, 12)

                if showLocation {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin")
                            .font(.system(size: 14))
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(14))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
            .frame(width: 1080)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(width: 1080, height: 1920)
        .background(Color.clear)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Helper Components

struct TornEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))

        let numberOfTeeth = Int(rect.width / 8)
        let toothWidth = rect.width / CGFloat(numberOfTeeth)

        for i in 0..<numberOfTeeth {
            let x1 = CGFloat(i) * toothWidth
            let x2 = x1 + toothWidth / 2
            let x3 = x1 + toothWidth

            path.addLine(to: CGPoint(x: x1, y: rect.height))
            path.addLine(to: CGPoint(x: x2, y: 0))
            path.addLine(to: CGPoint(x: x3, y: rect.height))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        return path
    }
}

struct DashedDivider: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

struct ReceiptStatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(SwissColors.black)

            Text(label)
                .font(SwissTypography.monoLabel(9))
                .foregroundColor(SwissColors.gray400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct CheckeredPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let squareSize: CGFloat = 20
                let rows = Int(geometry.size.height / squareSize)
                let columns = Int(geometry.size.width / squareSize)

                for row in 0..<rows {
                    for column in 0..<columns {
                        if (row + column) % 2 == 0 {
                            let x = CGFloat(column) * squareSize
                            let y = CGFloat(row) * squareSize
                            path.addRect(CGRect(x: x, y: y, width: squareSize, height: squareSize))
                        }
                    }
                }
            }
            .fill(Color.gray.opacity(0.2))

            Rectangle()
                .fill(Color.white.opacity(0.1))
        }
    }
}

// MARK: - Swiss Quick Share Button
struct SwissQuickShareButton: View {
    let icon: String
    let label: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(SwissColors.black)
                    .frame(width: 48, height: 48)
                    .background(SwissColors.gray50)
                    .overlay(
                        Rectangle()
                            .stroke(SwissColors.gray200, lineWidth: 1)
                    )

                Text(label)
                    .font(SwissTypography.monoLabel(9))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(SwissColors.gray500)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = [.addToReadingList, .assignToContact]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)  // Changed from (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
