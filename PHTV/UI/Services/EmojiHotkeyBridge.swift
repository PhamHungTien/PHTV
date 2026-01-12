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
        NSLog("BRIDGE-START")
        print("BRIDGE-START-PRINT")

        // Force initialization - this will trigger the singleton's init()
        let manager = EmojiHotkeyManager.shared

        NSLog("BRIDGE-AFTER-SHARED")
        print("BRIDGE-AFTER-SHARED-PRINT")

        NSLog("[EmojiHotkeyBridge] Manager object: %@", String(describing: manager))
    }
}
