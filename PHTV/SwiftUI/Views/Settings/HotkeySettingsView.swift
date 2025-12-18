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
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hotkey Configuration
                SettingsCard(title: "Phím tắt chuyển chế độ", icon: "command.circle.fill") {
                    HotkeyConfigView()
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    HotkeySettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
