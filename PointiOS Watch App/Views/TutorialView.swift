//
//  TutorialView.swift
//  Point 
//
//  Created by Bryson Hill II on 6/28/25.
//


import SwiftUI

struct TutorialView: View {
    @Binding var showTutorial: Bool
    @State private var currentPage = 0
    
    let tutorialPages = [
        TutorialPage(
            title: "Welcome to Point",
            description: "Track scores for pickleball, tennis, and padel with ease",
            imageName: "sportscourt",
            imageColor: .green
        ),
        TutorialPage(
            title: "Tap to Score",
            description: "Tap your side when you win a rally\nTap opponent's side when they win",
            imageName: "hand.tap",
            imageColor: .blue
        ),
        TutorialPage(
            title: "Track Serves",
            description: "Green dots show who's serving\nIn doubles, two dots track first/second server",
            imageName: "circle.fill",
            imageColor: Color(hex: "CFFE76") // Your green color
        ),
        TutorialPage(
            title: "Game History",
            description: "All your games are saved automatically\nView stats and match results anytime",
            imageName: "clock.arrow.circlepath",
            imageColor: .orange
        )
    ]
    
    var body: some View {
        VStack(spacing: 15) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    finishTutorial()
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal)
            .padding(.top, 5)
            
            // Current page content
            TabView(selection: $currentPage) {
                ForEach(0..<tutorialPages.count, id: \.self) { index in
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: tutorialPages[index].imageName)
                            .font(.system(size: 45))
                            .foregroundColor(tutorialPages[index].imageColor)
                        
                        VStack(spacing: 10) {
                            Text(tutorialPages[index].title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text(tutorialPages[index].description)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
            // Next/Done button
            Button(action: {
                if currentPage < tutorialPages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    finishTutorial()
                }
            }) {
                Text(currentPage < tutorialPages.count - 1 ? "Next" : "Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(Color.black)
    }
    
    private func finishTutorial() {
        UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
        withAnimation {
            showTutorial = false
        }
    }
}

struct TutorialPage {
    let title: String
    let description: String
    let imageName: String
    let imageColor: Color
}