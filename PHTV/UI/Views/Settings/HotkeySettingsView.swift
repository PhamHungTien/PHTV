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

    private var hotkeyString: String {
        var parts: [String] = []
        if appState.switchKeyControl { parts.append("⌃") }
        if appState.switchKeyOption { parts.append("⌥") }
        if appState.switchKeyShift { parts.append("⇧") }
        if appState.switchKeyCommand { parts.append("⌘") }
        if appState.switchKeyCode != 0xFE {
            parts.append(appState.switchKeyName)
        }
        return parts.isEmpty ? "Chưa đặt" : parts.joined()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsHeaderView(
                    title: "Phím tắt",
                    subtitle: "Đặt phím tắt để chuyển chế độ gõ, tạm dừng và mở PHTV Picker nhanh.",
                    icon: "command.circle.fill"
                ) {
                    SettingsStatusPill(
                        text: "Chuyển chế độ: \(hotkeyString)",
                        color: hotkeyString == "Chưa đặt" ? .secondary : .accentColor
                    )
                }

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
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .settingsBackground()
    }
}

#Preview {
    HotkeySettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 700)
}
