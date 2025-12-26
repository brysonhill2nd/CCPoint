//
//  SettingsCard.swift
//  PointiOS
//
//  Swiss Minimalist Settings Components
//

import SwiftUI

// MARK: - Legacy Components (kept for compatibility)

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

// MARK: - Swiss Sport Settings Sheet

struct SwissSportSettingsSheet: View {
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
        VStack(spacing: 0) {
            // Swiss Header
            swissHeader

            ScrollView {
                VStack(spacing: 0) {
                    // Sport Icon & Title
                    VStack(spacing: 12) {
                        Text(sportEmoji)
                            .font(.system(size: 56))

                        Text("\(sport.uppercased()) RULES")
                            .font(SwissTypography.monoLabel(11))
                            .tracking(2)
                            .foregroundColor(SwissColors.gray400)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .overlay(
                        Rectangle()
                            .fill(SwissColors.gray)
                            .frame(height: 1),
                        alignment: .bottom
                    )

                    // Game Type
                    SwissSettingOption(
                        title: "Game Type",
                        options: ["Singles", "Doubles"],
                        selected: settings.preferredGameType.wrappedValue == "singles" ? "Singles" : "Doubles"
                    ) { selected in
                        settings.preferredGameType.wrappedValue = selected.lowercased()
                    }

                    // Score Limit (Pickleball only)
                    if sport.lowercased() == "pickleball" {
                        SwissSettingOption(
                            title: "Score Limit",
                            options: ["11 Pts", "15 Pts", "21 Pts"],
                            selected: scoreLimitLabel
                        ) { selected in
                            let value = Int(selected.replacingOccurrences(of: " Pts", with: "")) ?? 11
                            settings.wrappedValue.scoreLimit = value
                        }
                    }

                    // Win By Two
                    SwissSettingToggle(
                        title: "Win by Two",
                        subtitle: "Must win by at least 2 points",
                        isOn: settings.winByTwo
                    )

                    // Match Format
                    SwissSettingOption(
                        title: "Match Format",
                        options: ["Single", "Best of 3", "Best of 5"],
                        selected: matchFormatLabel
                    ) { selected in
                        switch selected {
                        case "Single":
                            settings.matchFormat.wrappedValue = "single"
                        case "Best of 3":
                            settings.matchFormat.wrappedValue = "bestOf3"
                        case "Best of 5":
                            settings.matchFormat.wrappedValue = "bestOf5"
                        default:
                            settings.matchFormat.wrappedValue = "single"
                        }
                    }

                    Color.clear.frame(height: 100)
                }
            }
        }
        .background(SwissColors.white)
    }

    // MARK: - Header
    private var swissHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Game Rules")
                    .font(SwissTypography.monoLabel(12))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .fontWeight(.bold)
                    .foregroundColor(SwissColors.black)

                Spacer()

                Button(action: {
                    appData.saveSettings()
                    WatchConnectivityManager.shared.syncSettingsToWatch()
                    dismiss()
                }) {
                    Text("Done")
                        .font(SwissTypography.monoLabel(11))
                        .textCase(.uppercase)
                        .tracking(1)
                        .fontWeight(.bold)
                        .foregroundColor(SwissColors.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(SwissColors.green)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Rectangle()
                .fill(SwissColors.gray)
                .frame(height: 1)
        }
    }

    private var sportEmoji: String {
        switch sport.lowercased() {
        case "pickleball": return "🥒"
        case "tennis": return "🎾"
        case "padel": return "🏓"
        default: return "🎾"
        }
    }

    private var scoreLimitLabel: String {
        let limit = settings.wrappedValue.scoreLimit ?? 11
        return "\(limit) Pts"
    }

    private var matchFormatLabel: String {
        switch settings.matchFormat.wrappedValue {
        case "single": return "Single"
        case "bestOf3": return "Best of 3"
        case "bestOf5": return "Best of 5"
        default: return "Single"
        }
    }
}

// MARK: - Swiss Setting Option (Segmented)

struct SwissSettingOption: View {
    let title: String
    let options: [String]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(SwissTypography.monoLabel(10))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(SwissColors.gray400)

            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button(action: { onSelect(option) }) {
                        Text(option.uppercased())
                            .font(SwissTypography.monoLabel(10))
                            .tracking(0.5)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(selected == option ? SwissColors.white : SwissColors.black)
                            .background(selected == option ? SwissColors.green : SwissColors.white)
                    }
                    .buttonStyle(.plain)

                    if option != options.last {
                        Rectangle()
                            .fill(SwissColors.gray)
                            .frame(width: 1)
                    }
                }
            }
            .overlay(
                Rectangle()
                    .stroke(SwissColors.green, lineWidth: 1)
            )
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .overlay(
            Rectangle()
                .fill(SwissColors.gray)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Swiss Setting Toggle

struct SwissSettingToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(SwissColors.black)

                Text(subtitle)
                    .font(SwissTypography.monoLabel(10))
                    .foregroundColor(SwissColors.gray400)
            }

            Spacer()

            // Swiss-style toggle
            Button(action: { isOn.toggle() }) {
                HStack(spacing: 0) {
                    Text("OFF")
                        .font(SwissTypography.monoLabel(9))
                        .tracking(0.5)
                        .foregroundColor(!isOn ? SwissColors.white : SwissColors.gray400)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(!isOn ? SwissColors.black : SwissColors.white)

                    Text("ON")
                        .font(SwissTypography.monoLabel(9))
                        .tracking(0.5)
                        .foregroundColor(isOn ? SwissColors.white : SwissColors.gray400)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isOn ? SwissColors.green : SwissColors.white)
                }
                .overlay(
                    Rectangle()
                        .stroke(SwissColors.gray, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .overlay(
            Rectangle()
                .fill(SwissColors.gray)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Legacy Sport Settings Sheet (kept for compatibility)

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
        // Redirect to Swiss version
        SwissSportSettingsSheet(sport: sport)
            .environmentObject(appData)
    }
}
