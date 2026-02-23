//
//  ClipboardHotkeyBridge.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

/// Bridge to initialize ClipboardHotkeyManager from Objective-C AppDelegate
@objc class ClipboardHotkeyBridge: NSObject {
    @MainActor @objc static func initializeClipboardHotkeyManager() {
        _ = ClipboardHotkeyManager.shared
    }

    @MainActor @objc static func refreshClipboardHotkeyRegistration() {
        ClipboardHotkeyManager.shared.refreshRegistrationFromAppState()
    }

    @MainActor @objc static func openClipboardHistory() {
        ClipboardHistoryManager.shared.show()
    }
}
