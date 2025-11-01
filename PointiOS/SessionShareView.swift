// SessionShareView.swift
import SwiftUI
import UIKit
import AVFoundation

struct SessionShareView: View {
    let sessionData: SessionSummary
    @Environment(\.dismiss) var dismiss
    @State private var selectedStyle: BackgroundStyle = .gradient1
    @State private var shareImage: UIImage? = nil
    @State private var showingShareSheet = false
    @State private var showLocation = true
    
    enum BackgroundStyle: String, CaseIterable {
        case gradient1 = "Ocean"
        case gradient2 = "Sunset"
        case gradient3 = "Forest"
        case day = "Day"
        case gradient4 = "Night"
        case transparent = "Camera"
        
        var gradient: LinearGradient? {
            switch self {
            case .gradient1:
                return LinearGradient(
                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .gradient2:
                return LinearGradient(
                    colors: [Color(hex: "#fa709a"), Color(hex: "#fee140")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .gradient3:
                return LinearGradient(
                    colors: [Color(hex: "#11998e"), Color(hex: "#38ef7d")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .day:
                return LinearGradient(
                    colors: [Color(hex: "#FFFFFF"), Color(hex: "#007BFF")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .gradient4:
                return LinearGradient(
                    colors: [Color(hex: "#0f0c29"), Color(hex: "#302b63")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .transparent:
                return nil
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top navigation bar
                    HStack {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Share Session")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: generateAndShare) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Preview card
                    ZStack {
                        // Background based on style
                        if selectedStyle == .transparent {
                            // Checkered pattern to indicate transparency
                            CheckeredPattern()
                                .frame(width: 300, height: 440)
                                .cornerRadius(20)
                        } else if let gradient = selectedStyle.gradient {
                            gradient
                                .frame(width: 300, height: 440)
                                .cornerRadius(20)
                        }
                        
                        // Card overlay
                        SessionStoryCard(
                            sessionData: sessionData,
                            backgroundStyle: selectedStyle,
                            showLocation: showLocation,
                            isPreview: true
                        )
                        .frame(width: 300, height: 440)
                    }
                    .padding(.top, 10)

                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Location toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showLocation.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                            Text("Show location")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(showLocation ? .white : .gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(showLocation ? Color.blue : Color.gray.opacity(0.3))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    
                    Spacer()
                        .frame(height: 15)
                    
                    // Style selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose Style")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.leading, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(BackgroundStyle.allCases, id: \.self) { style in
                                    StyleButton(
                                        style: style,
                                        isSelected: selectedStyle == style,
                                        action: { selectedStyle = style }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }
    
    private func generateAndShare() {
        // Generate full-screen Instagram story image (1080x1920)
        let renderer = ImageRenderer(
            content: InstagramStoryView(
                sessionData: sessionData,
                backgroundStyle: selectedStyle,
                showLocation: showLocation
            )
        )
        
        renderer.scale = 3.0 // High quality
        
        if let image = renderer.uiImage {
            if selectedStyle == .transparent {
                shareImage = image.withRenderingMode(.alwaysOriginal)
            } else {
                shareImage = image
            }
            showingShareSheet = true
        }
    }
}

// Full-screen Instagram Story View
struct InstagramStoryView: View {
    let sessionData: SessionSummary
    let backgroundStyle: SessionShareView.BackgroundStyle
    let showLocation: Bool
    
    var body: some View {
        ZStack {
            // Background
            if backgroundStyle == .transparent {
                // For transparent, create a clear background
                Color.clear
            } else if let gradient = backgroundStyle.gradient {
                gradient
                    .ignoresSafeArea()
            }
            
            // Content
            SessionStoryCard(
                sessionData: sessionData,
                backgroundStyle: backgroundStyle,
                showLocation: showLocation,
                isPreview: false
            )
        }
        .frame(width: 1080, height: 1920)
        .background(backgroundStyle == .transparent ? Color.clear : nil)
    }
}


// Updated card with proper scaling
struct SessionStoryCard: View {
    let sessionData: SessionSummary
    let backgroundStyle: SessionShareView.BackgroundStyle
    let showLocation: Bool
    let isPreview: Bool
    
    // Scale factors for full-screen vs preview
    private var scaleFactor: CGFloat {
        isPreview ? 1.0 : 3.6 // Scale up for Instagram story
    }
    
    private var cardWidth: CGFloat {
        isPreview ? 260 : 900
    }
    
    private var fontSize: (title: CGFloat, record: CGFloat, stats: CGFloat, label: CGFloat) {
        if isPreview {
            return (12, 70, 24, 13)
        } else {
            return (36, 180, 72, 36)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !isPreview {
                Spacer()
                    .frame(height: 420) // Top spacing for Instagram story
            }
            
            // Main content box
            VStack(spacing: 0) {
                // Logo
                if let logo = UIImage(named: "logo-trans") {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100 * scaleFactor, height: 50 * scaleFactor)
                        .padding(.top, 15 * scaleFactor)
                        .padding(.bottom, 10 * scaleFactor)
                } else {
                    // Fallback if logo not found
                    Text("PointiOS")
                        .font(.system(size: 28 * scaleFactor, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 15 * scaleFactor)
                        .padding(.bottom, 10 * scaleFactor)
                }
                
                // Record section
                VStack(spacing: 6 * scaleFactor) {
                    Text("TODAY'S RECORD")
                        .font(.system(size: fontSize.title, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(1.2 * scaleFactor)
                    
                    Text("\(sessionData.gamesWon) - \(sessionData.gamesPlayed - sessionData.gamesWon)")
                        .font(.system(size: fontSize.record, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 8 * scaleFactor)
                
                Spacer()
                    .frame(height: 35 * scaleFactor)
                
                // Stats row
                HStack(spacing: 45 * scaleFactor) {
                    VStack(spacing: 3 * scaleFactor) {
                        Text("\(Int(sessionData.totalTime / 60)) min")
                            .font(.system(size: fontSize.stats, weight: .bold))
                            .foregroundColor(.white)
                        Text("Time")
                            .font(.system(size: fontSize.label))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    VStack(spacing: 3 * scaleFactor) {
                        Text("\(Int(sessionData.calories))")
                            .font(.system(size: fontSize.stats, weight: .bold))
                            .foregroundColor(.white)
                        Text("Calories")
                            .font(.system(size: fontSize.label))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                    .frame(height: 25 * scaleFactor)
                
                // BPM section
                VStack(spacing: 3 * scaleFactor) {
                    Text("\(Int(sessionData.avgHeartRate))")
                        .font(.system(size: fontSize.stats, weight: .bold))
                        .foregroundColor(.white)
                    Text("Avg BPM")
                        .font(.system(size: fontSize.label))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 20 * scaleFactor)
            }
            .frame(width: cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 22 * scaleFactor)
                    .fill(backgroundStyle == .transparent ?
                          Color.black.opacity(0.4) :
                          Color.black.opacity(0.25))
            )
            
            if !isPreview {
                Spacer()
                    .frame(height: 100) // Bottom spacing
            }
            
            // Location section
            if showLocation {
                HStack(spacing: 6 * scaleFactor) {
                    Image(systemName: "location.fill")
                        .font(.system(size: isPreview ? 16 : 48))
                    Text(sessionData.location)
                        .font(.system(size: isPreview ? 18 : 54, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.top, isPreview ? 25 : 50)
                .transition(.opacity.combined(with: .scale))
            }
            
            if !isPreview {
                Spacer()
                    .frame(height: 300) // Extra bottom padding for Instagram
            }
        }
    }
}

// MARK: - Helper Components

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

struct StyleButton: View {
    let style: SessionShareView.BackgroundStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    if let gradient = style.gradient {
                        gradient
                            .frame(width: 55, height: 75)
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 55, height: 75)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 55, height: 75)
                    }
                }
                
                Text(style.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
        }
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
