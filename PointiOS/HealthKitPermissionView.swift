//
//  HealthKitPermissionView.swift
//  PointiOS
//
//  Created by Bryson Hill II on 8/7/25.
//


//
//  HealthKitPermissionView.swift
//  PointiOS
//
//  Permission request and display view for HealthKit
//

import SwiftUI
import HealthKit

struct HealthKitPermissionView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var showingPermissionAlert = false
    @State private var permissionError: String?
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Health Integration")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Connect to Apple Health to track your workouts")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Status Section
            VStack(spacing: 20) {
                HealthDataRow(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: "Active Calories",
                    value: healthKitManager.isAuthorized ? "\(Int(healthKitManager.todaysCalories)) kcal" : "Not connected",
                    isConnected: healthKitManager.isAuthorized
                )
                
                HealthDataRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Heart Rate",
                    value: healthKitManager.isAuthorized ? "\(Int(healthKitManager.averageHeartRate)) bpm" : "Not connected",
                    isConnected: healthKitManager.isAuthorized
                )
                
                HealthDataRow(
                    icon: "person.fill",
                    iconColor: .blue,
                    title: "Age",
                    value: healthKitManager.isAuthorized ? 
                        (healthKitManager.getFormattedAge()) : "Not connected",
                    isConnected: healthKitManager.isAuthorized
                )
                
                if let ageGroup = healthKitManager.getAgeGroup() {
                    Text("Competition Group: \(ageGroup)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Connect Button
            if !healthKitManager.isAuthorized {
                Button(action: requestHealthKitPermission) {
                    HStack {
                        Image(systemName: "heart.text.square")
                        Text("Connect to Apple Health")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to Apple Health")
                            .foregroundColor(.green)
                    }
                    
                    Button("Refresh Data") {
                        healthKitManager.fetchTodaysData()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .onAppear {
            // Check if already authorized
            if healthKitManager.isAuthorized {
                healthKitManager.fetchTodaysData()
            }
        }
        .alert("Health Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionError ?? "Please enable Health access in Settings to track your workouts.")
        }
    }
    
    private func requestHealthKitPermission() {
        healthKitManager.requestAuthorization { success, error in
            if !success {
                if let error = error {
                    permissionError = error.localizedDescription
                } else {
                    permissionError = "Please grant all requested permissions to use this feature."
                }
                showingPermissionAlert = true
            }
        }
    }
}

struct HealthDataRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let isConnected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(isConnected ? .primary : .gray)
            }
            
            Spacer()
            
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Integration Helper
struct HealthKitIntegrationButton: View {
    @ObservedObject var healthKitManager: HealthKitManager
    
    var body: some View {
        if !healthKitManager.isAuthorized {
            Button(action: {
                healthKitManager.requestAuthorization { _, _ in }
            }) {
                Label("Enable Health Tracking", systemImage: "heart.text.square")
                    .foregroundColor(.red)
            }
        } else {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Health Tracking Active")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    HealthKitPermissionView()
}