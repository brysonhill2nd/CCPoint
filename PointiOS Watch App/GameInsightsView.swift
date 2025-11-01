//
//  GameInsightsView.swift
//  Point 
//
//  Created by Bryson Hill II on 6/27/25.
//


//
//  GameInsightsView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/26/25.
//

import SwiftUI

struct GameInsightsView: View {
    let gameRecord: GameRecord
    let insights: GameInsights
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(insights.gameStory.headline)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(gameRecord.scoreDisplay)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        
                        if gameRecord.winner == "You" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    
                    Text(gameRecord.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Game Story
                if !insights.gameStory.moments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game Story")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(insights.gameStory.moments.enumerated()), id: \.offset) { index, moment in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(moment.icon)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(moment.description)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        
                                        // Add connecting line for all but last
                                        if index < insights.gameStory.moments.count - 1 {
                                            Rectangle()
                                                .fill(Color.secondary.opacity(0.3))
                                                .frame(width: 2, height: 20)
                                                .padding(.leading, 8)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Key Stats
                VStack(spacing: 15) {
                    Text("Key Stats")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCard(
                            icon: "flame",
                            value: "\(insights.percentageInLead)%",
                            label: "Time in Lead"
                        )
                        
                        StatCard(
                            icon: "arrow.left.arrow.right",
                            value: "\(insights.leadChanges)",
                            label: "Lead Changes"
                        )
                        
                        if insights.longestRun.points >= 3 {
                            StatCard(
                                icon: "bolt.fill",
                                value: "\(insights.longestRun.points)",
                                label: "Best Run"
                            )
                        }
                        
                        if insights.comebackSize > 0 {
                            StatCard(
                                icon: "arrow.turn.up.right",
                                value: "\(insights.comebackSize)",
                                label: "Comeback From"
                            )
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // Insights
                if !insights.gameStory.insights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insights")
                            .font(.headline)
                        
                        ForEach(insights.gameStory.insights, id: \.self) { insight in
                            HStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 6, height: 6)
                                Text(insight)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}