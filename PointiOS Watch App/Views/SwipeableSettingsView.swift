//
//  SwipeableSettingsView.swift
//  ClaudePoint
//
//  Created by Bryson Hill II on 5/23/25.
//

import SwiftUI

struct SwipeableSettingsView: View {
    @State private var currentPage = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                PickleballSettingsPageView()
                    .tag(0)
                
                TennisSettingsPageView()
                    .tag(1)
                
                PadelSettingsPageView()
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
