//
//  SettingsCard.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 6/6/25.
//


//
//  SettingsCard.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//

import SwiftUI

struct SettingsCard: View {
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(value)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
