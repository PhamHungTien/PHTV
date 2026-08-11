//
//  EmojiHotkeyBridge.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Emoji Hotkey Bridge

/// Keeps AppDelegate integration isolated from the hotkey implementation.
@objc class EmojiHotkeyBridge: NSObject {
    @MainActor @objc static func initializeEmojiHotkeyManager() {
        // Force initialization - this will trigger the singleton's init()
        _ = EmojiHotkeyManager.shared
    }

    @MainActor @objc static func refreshEmojiHotkeyRegistration() {
        EmojiHotkeyManager.shared.refreshRegistrationFromAppState()
    }

    @MainActor @objc static func openEmojiPicker() {
        EmojiPickerManager.shared.show()
    }
}
