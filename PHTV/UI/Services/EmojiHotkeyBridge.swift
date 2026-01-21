//
//  EmojiHotkeyBridge.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Emoji Hotkey Bridge for Objective-C

/// Bridge to initialize EmojiHotkeyManager from Objective-C AppDelegate
@objc class EmojiHotkeyBridge: NSObject {
    @MainActor @objc static func initializeEmojiHotkeyManager() {
        // Force initialization - this will trigger the singleton's init()
        _ = EmojiHotkeyManager.shared
    }
}
