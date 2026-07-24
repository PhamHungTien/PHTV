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
    static func requestOpenWindow() {
        SettingsWindowHelper.openSettingsWindow()
    }
}
