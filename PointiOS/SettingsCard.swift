//
//  SettingsCard.swift
//  PointiOS
//
//  Created by Bryson Hill II on 7/20/25.
//


// SettingsComponents.swift
import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            content
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
    }
}

struct SportSettingsRow: View {
    let icon: String
    let sport: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.title2)

                Text(sport)
                    .font(.title3)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .green))
        }
    }
}

struct ActionRow: View {
    let title: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SportSettingsSheet: View {
    let sport: String
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss

    private var settings: Binding<AppData.SportGameSettings> {
        switch sport.lowercased() {
        case "pickleball":
            return $appData.userSettings.pickleballSettings
        case "tennis":
            return $appData.userSettings.tennisSettings
        case "padel":
            return $appData.userSettings.padelSettings
        default:
            return $appData.userSettings.pickleballSettings
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(sportEmoji)
                            .font(.system(size: 60))

                        Text("\(sport.capitalized) Rules")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.top)

                    // Game Type Setting
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game Type")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Picker("Game Type", selection: settings.preferredGameType) {
                            Text("Singles").tag("singles")
                            Text("Doubles").tag("doubles")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)

                    // Score Limit (Pickleball only)
                    if sport.lowercased() == "pickleball" {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Score Limit")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Picker("Score Limit", selection: Binding(
                                get: { settings.wrappedValue.scoreLimit ?? 11 },
                                set: { settings.wrappedValue.scoreLimit = $0 }
                            )) {
                                Text("11 Points").tag(11)
                                Text("15 Points").tag(15)
                                Text("21 Points").tag(21)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.horizontal)
                    }

                    // Win by Two
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: settings.winByTwo) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Win by Two")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("Must win by at least 2 points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    .padding(.horizontal)

                    // Match Format
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Match Format")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Picker("Match Format", selection: settings.matchFormat) {
                            Text("Single Game").tag("single")
                            Text("Best of 3").tag("bestOf3")
                            Text("Best of 5").tag("bestOf5")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        appData.saveSettings()
                        WatchConnectivityManager.shared.syncSettingsToWatch()
                        dismiss()
                    }
                }
            }
        }
    }

    private var sportEmoji: String {
        switch sport.lowercased() {
        case "pickleball":
            return "🥒"
        case "tennis":
            return "🎾"
        case "padel":
            return "🏓"
        default:
            return "🎾"
        }
    }
}