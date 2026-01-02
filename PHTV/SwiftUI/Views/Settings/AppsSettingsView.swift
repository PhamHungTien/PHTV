//
//  AppsSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct AppsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Smart Switch
                SettingsCard(title: "Chuyển đổi thông minh", icon: "brain.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "arrow.left.arrow.right",
                            iconColor: .accentColor,
                            title: "Chuyển thông minh theo ứng dụng",
                            subtitle: "Tự động chuyển Việt/Anh theo từng ứng dụng",
                            isOn: $appState.useSmartSwitchKey
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "memorychip.fill",
                            iconColor: .accentColor,
                            title: "Nhớ bảng mã theo ứng dụng",
                            subtitle: "Lưu bảng mã riêng cho từng ứng dụng",
                            isOn: $appState.rememberCode
                        )
                    }
                }

                // Excluded Apps
                SettingsCard(title: "Loại trừ ứng dụng", icon: "app.badge.fill") {
                    ExcludedAppsView()
                }

                // Send Key Step By Step
                SettingsCard(title: "Gửi từng phím", icon: "keyboard.badge.ellipsis") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "keyboard.badge.ellipsis",
                            iconColor: .accentColor,
                            title: "Bật gửi từng phím",
                            subtitle: "Gửi từng ký tự một (chậm nhưng ổn định hơn)",
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
        .settingsBackground()
    }
}

#Preview {
    AppsSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
