//
//  SendKeyStepByStepAppsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct SendKeyStepByStepAppsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.sendKeyStepByStepApps.isEmpty {
                AppSelectionEmptyStateView(
                    iconName: "keyboard.badge.ellipsis",
                    title: "Chưa có quy tắc ứng dụng",
                    subtitle: "Thêm ứng dụng cần tự động bật chế độ này",
                    showsQuickActions: false,
                    onPickRunningApps: {},
                    onPickFromApplications: {}
                )
                .transition(.opacity)
            } else {
                AppSelectionList(apps: appState.sendKeyStepByStepApps) { app in
                    appState.removeSendKeyStepByStepApp(app)
                }
                .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: appState.sendKeyStepByStepApps
        )
    }
}

#Preview {
    SendKeyStepByStepAppsView()
        .environment(AppState.shared)
        .frame(width: 400)
        .padding()
}
