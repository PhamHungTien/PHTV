//
//  AdvancedSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Advanced Typing Options
                SettingsCard(title: "Phụ âm nâng cao", icon: "character.textbox") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "character",
                            iconColor: themeManager.themeColor,
                            title: "Phụ âm Z, F, W, J",
                            subtitle: "Cho phép nhập các phụ âm ngoại lai",
                            isOn: $appState.allowConsonantZFWJ
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.right.circle.fill",
                            iconColor: themeManager.themeColor,
                            title: "Phụ âm đầu nhanh",
                            subtitle: "Gõ f → ph, j → gi, w → qu...",
                            isOn: $appState.quickStartConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.left.circle.fill",
                            iconColor: themeManager.themeColor,
                            title: "Phụ âm cuối nhanh",
                            subtitle: "Gõ g → ng, h → nh, k → ch...",
                            isOn: $appState.quickEndConsonant
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .settingsBackground()
    }
}

#Preview {
    AdvancedSettingsView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
        .frame(width: 500, height: 600)
}
