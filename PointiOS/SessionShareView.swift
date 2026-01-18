// SessionShareView.swift
import SwiftUI
import UIKit
import AVFoundation

struct SessionShareView: View {
    let sessionData: SessionSummary
    @Environment(\.dismiss) var dismiss
    @State private var selectedStyle: ShareStyle = .storyOverlay
    @State private var shareImage: UIImage? = nil
    @State private var showingShareSheet = false
    @State private var showLocation = true
    @State private var storyLightMode = false


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
                Text("Share to: Instagram Story")
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

                    if selectedStyle == .storyOverlay {
                        HStack(spacing: 16) {
                            Toggle(isOn: $storyLightMode) {
                                Text("Light Mode")
                                    .font(SwissTypography.monoLabel(10))
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .foregroundColor(SwissColors.gray400)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: SwissColors.green))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }

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

                    // Action Buttons - Save to Photos and Share for all styles
                    HStack(spacing: 12) {
                        Button(action: saveToPhotos) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 16))
                                Text("Save to Photos")
                            }
                        }
                        .buttonStyle(SwissSecondaryButtonStyle())

                        Button(action: generateAndShare) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16))
                                Text("Share")
                            }
                        }
                        .buttonStyle(SwissPrimaryButtonStyle())
                    }
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
                // Checkered pattern shows transparency
                CheckeredPattern()
                    .cornerRadius(12)
                CameraOverlayCard(sessionData: sessionData, showLocation: showLocation)
            }
            .aspectRatio(9/16, contentMode: .fit)
            .padding(.horizontal, 24)
        case .storyOverlay:
            StoryOverlayCard(sessionData: sessionData, showLocation: showLocation, isLightMode: storyLightMode)
                .cornerRadius(12)
                .padding(.horizontal, 24)
        }
    }

    private func generateAndShare() {
        guard let image = renderImage(for: selectedStyle) else { return }
        shareImage = image
        showingShareSheet = true
    }

    private func shareToInstagramStories() {
        let sourceApp = Bundle.main.bundleIdentifier ?? "pointapp.app"
        guard let url = URL(string: "instagram-stories://share?source_application=\(sourceApp)") else { return }
        guard UIApplication.shared.canOpenURL(url) else { return }

        guard let image = renderImage(for: selectedStyle),
              let pngData = image.pngData() else {
            return
        }

        // All cards now have transparent backgrounds - share as stickers so users can position over their photos
        let pasteboardKey = "com.instagram.sharedSticker.stickerImage"

        UIPasteboard.general.setItems(
            [[pasteboardKey: pngData]],
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )

        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func renderImage(for style: ShareStyle) -> UIImage? {
        let content = exportView(for: style)
        let renderer = ImageRenderer(content: content)
        // All exports are native 1080x1920
        renderer.scale = 1.0
        // All styles have transparent backgrounds so cards can be placed over photos
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
            return AnyView(CameraExport(sessionData: sessionData, showLocation: showLocation))
        case .storyOverlay:
            return AnyView(StoryOverlayExport(sessionData: sessionData, showLocation: showLocation, isLightMode: storyLightMode))
        }
    }

    private func saveToPhotos() {
        guard let image = renderImage(for: selectedStyle) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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

            // Content
            VStack(spacing: 20) {
                // Logo
                PointWordmark(size: 28, textColor: .white)

                // Score
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(sessionData.gamesWon)")
                        .font(.system(size: 72, weight: .bold))
                        .tracking(-3)
                        .foregroundColor(SwissColors.green)
                    Text("-")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text("\(sessionData.gamesPlayed - sessionData.gamesWon)")
                        .font(.system(size: 72, weight: .bold))
                        .tracking(-3)
                        .foregroundColor(.white.opacity(0.5))
                }

                // Session Record label
                Text("SESSION RECORD")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.7))

                // Stats
                HStack(spacing: 28) {
                    VStack(spacing: 6) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("TIME")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    VStack(spacing: 6) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("CAL")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    VStack(spacing: 6) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                if showLocation {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(sessionData.location)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(24)
        }
        .cornerRadius(12)
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

// MARK: - Camera Overlay Card (white text only, for photo backgrounds)
struct CameraOverlayCard: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 80) // Push content down to show positioning

            // Logo - larger to match score visual weight
            PointWordmark(size: 36, textColor: .white)
                .shadow(color: .black.opacity(0.7), radius: 6, x: 0, y: 3)

            // Score - large white text
            Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                .font(.system(size: 80, weight: .black))
                .tracking(-2)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 5)

            // Label - bolder and larger
            Text("SESSION RECORD")
                .font(.system(size: 14, weight: .bold))
                .tracking(4)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

            // Stats row - white text
            HStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text(formatTime(sessionData.totalTime))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("TIME")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.85))
                }
                VStack(spacing: 6) {
                    Text("\(Int(sessionData.calories))")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("CAL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.85))
                }
                VStack(spacing: 6) {
                    Text("\(Int(sessionData.avgHeartRate))")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("BPM")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

            if showLocation {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(sessionData.location)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                .padding(.top, 12)
            }

            Spacer()
        }
        .padding(24)
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

// MARK: - Camera Export (transparent PNG with white text for sticker use)
// Instagram Story dimensions: 1080x1920
struct CameraExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        // White text on transparent background - positioned below center to avoid IG UI
        VStack(spacing: 48) {
            Spacer()
                .frame(height: 400) // Push content down to avoid Instagram's top UI

            // Logo - large to match score visual weight
            PointWordmark(size: 80, textColor: .white)
                .shadow(color: .black.opacity(0.9), radius: 12, x: 0, y: 6)

            // Big score
            Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                .font(.system(size: 160, weight: .black))
                .tracking(-4)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.9), radius: 20, x: 0, y: 10)

            // Label - bolder and larger
            Text("SESSION RECORD")
                .font(.system(size: 28, weight: .bold))
                .tracking(6)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.9), radius: 8, x: 0, y: 4)

            // Stats row
            HStack(spacing: 64) {
                VStack(spacing: 12) {
                    Text(formatTime(sessionData.totalTime))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    Text("TIME")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.9))
                }
                VStack(spacing: 12) {
                    Text("\(Int(sessionData.calories))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    Text("CAL")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.9))
                }
                VStack(spacing: 12) {
                    Text("\(Int(sessionData.avgHeartRate))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    Text("BPM")
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .shadow(color: .black.opacity(0.9), radius: 8, x: 0, y: 4)

            if showLocation {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                    Text(sessionData.location)
                        .font(.system(size: 24, weight: .semibold))
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.9), radius: 6, x: 0, y: 3)
                .padding(.top, 24)
            }

            Spacer()
        }
        .padding(.horizontal, 80)
        .frame(width: 1080, height: 1920)
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
    var isLightMode: Bool = false

    var body: some View {
        let textColor: Color = isLightMode ? .black : .white
        let bgTop = isLightMode ? Color.white : Color.black
        let bgBottom = isLightMode ? Color(hex: "F1F4F2") : Color(hex: "0B0F0D")
        let accent = Color(hex: "6EEA4F")

        ZStack {
            LinearGradient(
                colors: [bgTop, bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 16) {
                // Logo - large
                PointWordmark(size: 36, textColor: textColor)
                    .padding(.top, 12)

                Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                    .font(.system(size: 80, weight: .black))
                    .tracking(-3)
                    .foregroundColor(textColor)

                Text("SESSION RECORD")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(3)
                    .foregroundColor(accent)

                HStack(spacing: 18) {
                    StoryStatBlock(
                        value: formatTime(sessionData.totalTime),
                        label: "TIME",
                        textColor: textColor,
                        labelColor: textColor.opacity(0.6),
                        backgroundColor: isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.06),
                        borderColor: isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1)
                    )
                    StoryStatBlock(
                        value: "\(Int(sessionData.calories))",
                        label: "CAL",
                        textColor: textColor,
                        labelColor: textColor.opacity(0.6),
                        backgroundColor: isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.06),
                        borderColor: isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1)
                    )
                    StoryStatBlock(
                        value: "\(Int(sessionData.avgHeartRate))",
                        label: "BPM",
                        textColor: textColor,
                        labelColor: textColor.opacity(0.6),
                        backgroundColor: isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.06),
                        borderColor: isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1)
                    )
                }
                .padding(.top, 8)

                if showLocation {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(sessionData.location)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(textColor.opacity(0.85))
                }

                Spacer()

                StoryPerspectiveCourt(isLightMode: isLightMode)
                    .frame(height: 120)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 520)
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

private struct StoryStatBlock: View {
    let value: String
    let label: String
    var textColor: Color = .white
    var labelColor: Color = .white.opacity(0.6)
    var backgroundColor: Color = Color.white.opacity(0.06)
    var borderColor: Color = Color.white.opacity(0.1)

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(textColor)
            Text(label)
                .font(SwissTypography.monoLabel(9))
                .tracking(1)
                .foregroundColor(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

private struct StoryPerspectiveCourt: View {
    var isLightMode: Bool = false

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            let topWidth: CGFloat = width * 0.40
            let bottomWidth: CGFloat = width * 0.90
            let topY: CGFloat = 0
            let bottomY: CGFloat = height
            let baselineY: CGFloat = height * 0.65
            let serviceLineY: CGFloat = topY + (bottomY - topY) * 0.30

            let centerX = width / 2
            let topLeftX = centerX - topWidth / 2
            let topRightX = centerX + topWidth / 2
            let bottomLeftX = centerX - bottomWidth / 2
            let bottomRightX = centerX + bottomWidth / 2

            func xAtY(_ y: CGFloat, isLeft: Bool) -> CGFloat {
                let t = (y - topY) / (bottomY - topY)
                if isLeft {
                    return topLeftX + t * (bottomLeftX - topLeftX)
                } else {
                    return topRightX + t * (bottomRightX - topRightX)
                }
            }

            let lineOpacity: Double = isLightMode ? 0.10 : 0.12
            let lineColor = Color.gray

            var courtPath = Path()
            courtPath.move(to: CGPoint(x: topLeftX, y: topY))
            courtPath.addLine(to: CGPoint(x: topRightX, y: topY))
            courtPath.addLine(to: CGPoint(x: bottomRightX, y: bottomY))
            courtPath.addLine(to: CGPoint(x: bottomLeftX, y: bottomY))
            courtPath.closeSubpath()
            context.fill(courtPath, with: .color(Color(hex: "1B2A24").opacity(isLightMode ? 0.16 : 0.22)))
            context.stroke(courtPath, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1)

            var serviceLinePath = Path()
            serviceLinePath.move(to: CGPoint(x: xAtY(serviceLineY, isLeft: true), y: serviceLineY))
            serviceLinePath.addLine(to: CGPoint(x: xAtY(serviceLineY, isLeft: false), y: serviceLineY))
            context.stroke(serviceLinePath, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1)

            var centerLinePath = Path()
            centerLinePath.move(to: CGPoint(x: centerX, y: serviceLineY))
            centerLinePath.addLine(to: CGPoint(x: centerX, y: baselineY))
            context.stroke(centerLinePath, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1)

            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: xAtY(baselineY, isLeft: true), y: baselineY))
            baselinePath.addLine(to: CGPoint(x: xAtY(baselineY, isLeft: false), y: baselineY))
            context.stroke(baselinePath, with: .color(lineColor.opacity(lineOpacity)), lineWidth: 1.3)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white.opacity(0.08), location: 0.25),
                    .init(color: .white.opacity(0.35), location: 0.55),
                    .init(color: .white, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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

// MARK: - Export Views (Instagram Story: 1080x1920)

struct SwissSessionReceiptExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        ZStack {
            // Transparent background
            Color.clear

            // Large card centered
            VStack(spacing: 32) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        PointWordmark(size: 56, textColor: SwissColors.black)
                        Text("Session Record")
                            .font(SwissTypography.monoLabel(20))
                            .textCase(.uppercase)
                            .tracking(2)
                            .foregroundColor(SwissColors.gray400)
                    }
                    Spacer()
                    Text(sessionData.gamesWon > (sessionData.gamesPlayed - sessionData.gamesWon) ? "W" : "L")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(sessionData.gamesWon > (sessionData.gamesPlayed - sessionData.gamesWon) ? SwissColors.green : SwissColors.red)
                }

                Rectangle()
                    .fill(SwissColors.gray300)
                    .frame(height: 2)

                // Score
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("WON")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(SwissColors.gray400)
                        Text("\(sessionData.gamesWon)")
                            .font(.system(size: 120, weight: .bold))
                            .tracking(-4)
                            .foregroundColor(SwissColors.green)
                    }
                    Text(":")
                        .font(.system(size: 72))
                        .foregroundColor(SwissColors.gray300)
                    VStack(spacing: 8) {
                        Text("LOST")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(SwissColors.gray400)
                        Text("\(sessionData.gamesPlayed - sessionData.gamesWon)")
                            .font(.system(size: 120, weight: .bold))
                            .tracking(-4)
                            .foregroundColor(SwissColors.gray400)
                    }
                }
                .padding(.vertical, 24)

                Rectangle()
                    .fill(SwissColors.gray300)
                    .frame(height: 2)

                // Stats row
                HStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("Time")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(SwissColors.gray400)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 10) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("Cal")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(SwissColors.gray400)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 10) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("BPM")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(SwissColors.gray400)
                    }
                    .frame(maxWidth: .infinity)
                }

                if showLocation {
                    Rectangle()
                        .fill(SwissColors.gray300)
                        .frame(height: 2)

                    HStack(spacing: 12) {
                        Image(systemName: "mappin")
                            .font(.system(size: 28))
                            .foregroundColor(SwissColors.gray400)
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(24))
                            .foregroundColor(SwissColors.black)
                    }
                    .padding(.vertical, 16)
                }

                // Footer
                VStack(spacing: 16) {
                    Text("pointapp.app")
                        .font(SwissTypography.monoLabel(18))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundColor(SwissColors.gray400)

                    HStack(spacing: 2) {
                        ForEach(0..<35, id: \.self) { _ in
                            Rectangle()
                                .fill(SwissColors.black)
                                .frame(width: CGFloat.random(in: 2...5), height: 48)
                        }
                    }
                }
                .padding(.top, 24)
            }
            .padding(56)
            .background(SwissColors.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(SwissColors.gray200, lineWidth: 2))
            .padding(.horizontal, 40) // Small margins on sides
        }
        .frame(width: 1080, height: 1920)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

struct SwissMinimalExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        ZStack {
            // Transparent background
            Color.clear

            // Large card centered
            VStack(spacing: 40) {
                // Big score
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(sessionData.gamesWon)")
                        .font(.system(size: 140, weight: .bold))
                        .tracking(-5)
                        .foregroundColor(SwissColors.green)
                    Text("-")
                        .font(.system(size: 90, weight: .bold))
                        .foregroundColor(SwissColors.gray300)
                    Text("\(sessionData.gamesPlayed - sessionData.gamesWon)")
                        .font(.system(size: 140, weight: .bold))
                        .tracking(-5)
                        .foregroundColor(SwissColors.gray400)
                }

                // Stats
                HStack(spacing: 48) {
                    VStack(spacing: 12) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("Duration")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(SwissColors.gray400)
                    }
                    VStack(spacing: 12) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("Calories")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(SwissColors.gray400)
                    }
                    VStack(spacing: 12) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(SwissColors.black)
                        Text("BPM")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(SwissColors.gray400)
                    }
                }

                if showLocation {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin")
                            .font(.system(size: 28))
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(22))
                    }
                    .foregroundColor(SwissColors.gray400)
                }

                // Logo
                PointWordmark(size: 48, textColor: SwissColors.black)
                    .opacity(0.6)
            }
            .padding(56)
            .background(SwissColors.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(SwissColors.green.opacity(0.3), lineWidth: 2))
            .padding(.horizontal, 40)
        }
        .frame(width: 1080, height: 1920)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

struct StravaStyleExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        ZStack {
            // Transparent background
            Color.clear

            // Large card with green gradient
            VStack(spacing: 36) {
                // Logo
                PointWordmark(size: 56, textColor: .white)

                // Big record
                Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                    .font(.system(size: 140, weight: .black))
                    .tracking(-4)
                    .foregroundColor(.white)

                Text("Session Record")
                    .font(SwissTypography.monoLabel(22))
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.8))

                // Stats row
                HStack(spacing: 48) {
                    VStack(spacing: 12) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text("Time")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    VStack(spacing: 12) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text("Cal")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    VStack(spacing: 12) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(SwissTypography.monoLabel(18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                if showLocation {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin")
                            .font(.system(size: 28))
                        Text(sessionData.location)
                            .font(SwissTypography.monoLabel(22))
                    }
                    .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(56)
            .background(
                LinearGradient(
                    colors: [SwissColors.green, SwissColors.green.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(24)
            .padding(.horizontal, 40)
        }
        .frame(width: 1080, height: 1920)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

struct SwissDarkExport: View {
    let sessionData: SessionSummary
    let showLocation: Bool

    var body: some View {
        ZStack {
            // Transparent background
            Color.clear

            // Large dark card
            VStack(spacing: 36) {
                // Logo
                PointWordmark(size: 64, textColor: .white)

                // Score
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(sessionData.gamesWon)")
                        .font(.system(size: 140, weight: .bold))
                        .tracking(-5)
                        .foregroundColor(SwissColors.green)
                    Text("-")
                        .font(.system(size: 90, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text("\(sessionData.gamesPlayed - sessionData.gamesWon)")
                        .font(.system(size: 140, weight: .bold))
                        .tracking(-5)
                        .foregroundColor(.white.opacity(0.5))
                }

                // Session Record label
                Text("SESSION RECORD")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(5)
                    .foregroundColor(.white.opacity(0.7))

                // Stats
                HStack(spacing: 48) {
                    VStack(spacing: 12) {
                        Text(formatTime(sessionData.totalTime))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text("TIME")
                            .font(.system(size: 18, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    VStack(spacing: 12) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text("CAL")
                            .font(.system(size: 18, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    VStack(spacing: 12) {
                        Text("\(Int(sessionData.avgHeartRate))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(.system(size: 18, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                if showLocation {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                        Text(sessionData.location)
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(56)
            .background(Color.black)
            .cornerRadius(24)
            .padding(.horizontal, 40)
        }
        .frame(width: 1080, height: 1920)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
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
    var isLightMode: Bool = false

    var body: some View {
        let textColor: Color = isLightMode ? .black : .white
        let bgTop = isLightMode ? Color.white : Color.black
        let bgBottom = isLightMode ? Color(hex: "F1F4F2") : Color(hex: "0B0F0D")
        let accent = Color(hex: "6EEA4F")

        ZStack {
            // Transparent background
            Color.clear

            // Large card with gradient
            VStack(spacing: 32) {
                // Logo
                PointWordmark(size: 64, textColor: textColor)

                Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                    .font(.system(size: 140, weight: .black))
                    .tracking(-4)
                    .foregroundColor(textColor)

                Text("SESSION RECORD")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(5)
                    .foregroundColor(accent)

                HStack(spacing: 24) {
                    StoryStatBlockLarge(
                        value: formatTime(sessionData.totalTime),
                        label: "TIME",
                        textColor: textColor,
                        labelColor: textColor.opacity(0.6),
                        backgroundColor: isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.06),
                        borderColor: isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1)
                    )
                    StoryStatBlockLarge(
                        value: "\(Int(sessionData.calories))",
                        label: "CAL",
                        textColor: textColor,
                        labelColor: textColor.opacity(0.6),
                        backgroundColor: isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.06),
                        borderColor: isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1)
                    )
                    StoryStatBlockLarge(
                        value: "\(Int(sessionData.avgHeartRate))",
                        label: "BPM",
                        textColor: textColor,
                        labelColor: textColor.opacity(0.6),
                        backgroundColor: isLightMode ? Color.black.opacity(0.06) : Color.white.opacity(0.06),
                        borderColor: isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1)
                    )
                }

                if showLocation {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                        Text(sessionData.location)
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundColor(textColor.opacity(0.85))
                }

                StoryPerspectiveCourt(isLightMode: isLightMode)
                    .frame(height: 200)
            }
            .padding(48)
            .background(
                LinearGradient(
                    colors: [bgTop, bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(24)
            .padding(.horizontal, 40)
        }
        .frame(width: 1080, height: 1920)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

private struct StoryStatBlockLarge: View {
    let value: String
    let label: String
    var textColor: Color = .white
    var labelColor: Color = .white.opacity(0.6)
    var backgroundColor: Color = Color.white.opacity(0.06)
    var borderColor: Color = Color.white.opacity(0.1)

    var body: some View {
        VStack(spacing: 12) {
            Text(value)
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(textColor)
            Text(label)
                .font(SwissTypography.monoLabel(16))
                .tracking(2)
                .foregroundColor(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(backgroundColor)
        .overlay(Rectangle().stroke(borderColor, lineWidth: 1))
    }
}

private struct FullScreenShareExport: View {
    let content: AnyView
    let background: Color
    let scale: CGFloat

    var body: some View {
        ZStack {
            background
            content
                .scaleEffect(scale)
        }
        .frame(width: 1080, height: 1920)
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
