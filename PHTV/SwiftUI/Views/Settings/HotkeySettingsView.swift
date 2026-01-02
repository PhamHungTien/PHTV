//
//  HotkeySettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct HotkeySettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Hotkey Status Card
                currentHotkeyCard

                // Hotkey Configuration
                SettingsCard(title: "Phím tắt chuyển chế độ", icon: "command.circle.fill") {
                    HotkeyConfigView()
                }

                // Pause Key Configuration
                SettingsCard(title: "Tạm dừng gõ tiếng Việt", icon: "pause.circle.fill") {
                    PauseKeyConfigView()
                }

                // PHTV Picker Hotkey
                SettingsCard(title: "PHTV Picker", icon: "smiley.fill") {
                    EmojiHotkeyConfigView()
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .settingsBackground()
    }

    // MARK: - Current Hotkey Status Card

    private var currentHotkeyCard: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "keyboard.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Phím tắt hiện tại")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(currentHotkeyDisplay)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Language indicator
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                    Text("VI")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                    Text("EN")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Helpers

    private var currentHotkeyDisplay: String {
        var parts: [String] = []
        if appState.switchKeyFn { parts.append("fn") }
        if appState.switchKeyControl { parts.append("⌃") }
        if appState.switchKeyShift { parts.append("⇧") }
        if appState.switchKeyCommand { parts.append("⌘") }
        if appState.switchKeyOption { parts.append("⌥") }

        // Only add key name if it's a real key (not modifier-only mode)
        if appState.switchKeyCode != 0xFE && !appState.switchKeyName.isEmpty && appState.switchKeyName != "Không" {
            parts.append(appState.switchKeyName)
        }

        return parts.isEmpty ? "Chưa đặt" : parts.joined(separator: " + ")
    }
}

#Preview {
    HotkeySettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 700)
}
