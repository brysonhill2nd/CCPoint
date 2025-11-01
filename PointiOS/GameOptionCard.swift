//
//  GameOptionCard.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/20/25.
//


// GameComponents.swift
import SwiftUI

struct GameOptionCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 20) {
                Text(icon)
                    .font(.system(size: 40))
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color == .gray ? Color.gray.opacity(0.2) : color)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickStatsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Stats")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 0) {
                VStack {
                    Text("8")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Wins This Week")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack {
                    Text("2.5h")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Avg Game Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.2))
        )
    }
}