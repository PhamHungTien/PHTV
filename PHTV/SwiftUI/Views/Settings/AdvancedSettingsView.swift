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
                SettingsCard(title: "Tùy chọn nâng cao", icon: "gearshape.2.fill") {
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
                            subtitle: "Gõ nhanh phụ âm đầu",
                            isOn: $appState.quickStartConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.left.circle.fill",
                            iconColor: themeManager.themeColor,
                            title: "Phụ âm cuối nhanh",
                            subtitle: "Gõ nhanh phụ âm cuối",
                            isOn: $appState.quickEndConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "memorychip.fill",
                            iconColor: themeManager.themeColor,
                            title: "Nhớ bảng mã",
                            subtitle: "Lưu bảng mã khi đóng ứng dụng",
                            isOn: $appState.rememberCode
                        )
                    }
                }

                // Send Key Step By Step
                SettingsCard(title: "Gửi từng phím", icon: "keyboard.badge.ellipsis") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "keyboard.badge.ellipsis",
                            iconColor: themeManager.themeColor,
                            title: "Bật gửi từng phím",
                            subtitle: "Gửi từng ký tự một (chậm nhưng ổn định)",
                            isOn: $appState.sendKeyStepByStep
                        )
                    }
                }

                // Send Key Step By Step Apps
                SettingsCard(title: "Ứng dụng gửi từng phím", icon: "app.badge.fill") {
                    SendKeyStepByStepAppsView()
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    AdvancedSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
