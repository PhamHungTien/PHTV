//
//  SettingsWindowOpener.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

@MainActor
enum SettingsWindowOpener {
    static func requestOpenWindow(tab: SettingsTab) {
        AppState.shared.requestedSettingsTab = tab
        requestOpenWindow()
    }

    static func requestDonatePopover() {
        AppState.shared.donatePopoverRequested = true
        requestOpenWindow(tab: .about)
    }

    static func requestConvertTool() {
        AppState.shared.convertToolRequested = true
        requestOpenWindow(tab: .system)
    }

    static func requestOpenWindow() {
        SettingsWindowHelper.openSettingsWindow()
    }
}
