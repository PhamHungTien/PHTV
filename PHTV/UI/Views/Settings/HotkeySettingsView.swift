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
