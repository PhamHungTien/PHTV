//
//  Constants.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit

// MARK: - UserDefaults Keys

enum UserDefaultsKey {
    // MARK: - Input Method
    static let inputMethod = "InputMethod"
    static let inputType = "InputType"
    static let codeTable = "CodeTable"

    // MARK: - Spelling & Features
    static let spelling = "Spelling"
    static let modernOrthography = "ModernOrthography"
    static let quickTelex = "QuickTelex"
    static let restoreIfInvalidWord = "RestoreIfInvalidWord"
    static let sendKeyStepByStep = "SendKeyStepByStep"
    static let fixChromiumBrowser = "FixChromiumBrowser"
    static let useMacro = "UseMacro"
    static let useMacroInEnglishMode = "UseMacroInEnglishMode"
    static let autoCapsMacro = "vAutoCapsMacro"
    static let macroCategories = "macroCategories"
    static let useSmartSwitchKey = "UseSmartSwitchKey"
    static let upperCaseFirstChar = "UpperCaseFirstChar"
    static let allowConsonantZFWJ = "vAllowConsonantZFWJ"
    static let quickStartConsonant = "vQuickStartConsonant"
    static let quickEndConsonant = "vQuickEndConsonant"
    static let rememberCode = "vRememberCode"
    static let autoRestoreEnglishWord = "vAutoRestoreEnglishWord"

    // MARK: - Restore & Pause Keys
    static let restoreOnEscape = "vRestoreOnEscape"
    static let customEscapeKey = "vCustomEscapeKey"
    static let pauseKeyEnabled = "vPauseKeyEnabled"
    static let pauseKey = "vPauseKey"
    static let pauseKeyName = "vPauseKeyName"

    // MARK: - Emoji Hotkey
    static let enableEmojiHotkey = "vEnableEmojiHotkey"
    static let emojiHotkeyModifiers = "vEmojiHotkeyModifiers"
    static let emojiHotkeyKeyCode = "vEmojiHotkeyKeyCode"

    // MARK: - System Settings
    static let runOnStartup = "PHTV_RunOnStartup"
    static let runOnStartupLegacy = "RunOnStartup"
    static let performLayoutCompat = "vPerformLayoutCompat"
    static let showIconOnDock = "vShowIconOnDock"
    static let settingsWindowAlwaysOnTop = "vSettingsWindowAlwaysOnTop"
    static let safeMode = "SafeMode"
    static let enableLiquidGlassBackground = "vEnableLiquidGlassBackground"
    static let settingsBackgroundOpacity = "vSettingsBackgroundOpacity"

    // MARK: - Hotkey Settings
    static let switchKeyStatus = "SwitchKeyStatus"
    static let beepOnModeSwitch = "vBeepOnModeSwitch"

    // MARK: - Audio & Display
    static let beepVolume = "vBeepVolume"
    static let menuBarIconSize = "vMenuBarIconSize"
    static let useVietnameseMenubarIcon = "vUseVietnameseMenubarIcon"

    // MARK: - App Lists
    static let excludedApps = "ExcludedApps"
    static let sendKeyStepByStepApps = "SendKeyStepByStepApps"

    // MARK: - Sparkle Updates
    static let updateCheckInterval = "SUScheduledCheckInterval"
    static let betaChannelEnabled = "SUEnableBetaChannel"
    static let autoInstallUpdates = "vAutoInstallUpdates"

    // MARK: - Debug
    static let liveDebug = "PHTV_LIVE_DEBUG"
}

// MARK: - Notification Names

enum NotificationName {
    // MARK: - Language Changes
    static let languageChangedFromSwiftUI = NSNotification.Name("LanguageChangedFromSwiftUI")
    static let languageChangedFromBackend = NSNotification.Name("LanguageChangedFromBackend")
    static let languageChangedFromExcludedApp = NSNotification.Name("LanguageChangedFromExcludedApp")
    static let languageChangedFromSmartSwitch = NSNotification.Name("LanguageChangedFromSmartSwitch")
    static let languageChangedFromObjC = NSNotification.Name("LanguageChangedFromObjC")

    // MARK: - Settings Changes
    static let phtvSettingsChanged = NSNotification.Name("PHTVSettingsChanged")
    static let inputMethodChanged = NSNotification.Name("InputMethodChanged")
    static let codeTableChanged = NSNotification.Name("CodeTableChanged")
    static let hotkeyChanged = NSNotification.Name("HotkeyChanged")
    static let settingsResetToDefaults = NSNotification.Name("SettingsResetToDefaults")

    // MARK: - App Lists
    static let excludedAppsChanged = NSNotification.Name("ExcludedAppsChanged")
    static let sendKeyStepByStepAppsChanged = NSNotification.Name("SendKeyStepByStepAppsChanged")

    // MARK: - Emoji Hotkey
    static let emojiHotkeySettingsChanged = NSNotification.Name("EmojiHotkeySettingsChanged")

    // MARK: - System
    static let accessibilityStatusChanged = NSNotification.Name("AccessibilityStatusChanged")
    static let runOnStartupChanged = NSNotification.Name("RunOnStartupChanged")
    static let applicationWillTerminate = NSNotification.Name("ApplicationWillTerminate")

    // MARK: - UI Updates
    static let menuBarIconSizeChanged = NSNotification.Name("MenuBarIconSizeChanged")
    static let menuBarIconPreferenceChanged = NSNotification.Name("MenuBarIconPreferenceChanged")

    // MARK: - Updates
    static let checkForUpdatesResponse = NSNotification.Name("CheckForUpdatesResponse")
    static let updateCheckFrequencyChanged = NSNotification.Name("UpdateCheckFrequencyChanged")
    static let betaChannelChanged = NSNotification.Name("BetaChannelChanged")
    static let sparkleShowUpdateBanner = NSNotification.Name("SparkleShowUpdateBanner")
}

// MARK: - Key Codes

enum KeyCode {
    // MARK: - Special Keys
    static let noKey: UInt16 = 0xFE  // Modifier-only mode (no physical key)
    static let escape: UInt16 = 53
    static let leftOption: UInt16 = 58
    static let eKey: UInt16 = 14

    // MARK: - Modifier Masks (for SwitchKeyStatus encoding)
    static let controlMask = 0x100
    static let optionMask = 0x200
    static let commandMask = 0x400
    static let shiftMask = 0x800
    static let fnMask = 0x1000
    static let beepMask = 0x8000

    // MARK: - Key Name Mapping
    static let keyNames: [UInt16: String] = [
        // Letters
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
        0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
        0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
        0x10: "Y", 0x11: "T",

        // Numbers
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6",
        0x17: "5", 0x19: "9", 0x1A: "7", 0x1C: "8", 0x1D: "0",

        // Symbols
        0x18: "=", 0x1B: "-", 0x1E: "]", 0x21: "[", 0x27: "'",
        0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2F: ".",
        0x31: "Space", 0x32: "`",

        // More Letters
        0x1F: "O", 0x20: "U", 0x22: "I", 0x23: "P",
        0x25: "L", 0x26: "J", 0x28: "K", 0x2D: "N", 0x2E: "M",

        // Function Keys
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
        0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
        0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12"
    ]
}

// MARK: - Default Values

enum Defaults {
    // MARK: - Input Method
    static let inputMethod = InputMethod.telex
    static let codeTable = CodeTable.unicode

    // MARK: - Features
    static let checkSpelling = true
    static let useModernOrthography = true
    static let quickTelex = false
    static let restoreOnInvalidWord = false
    static let sendKeyStepByStep = false
    static let useMacro = true
    static let useMacroInEnglishMode = false
    static let autoCapsMacro = false
    static let useSmartSwitchKey = true
    static let upperCaseFirstChar = false
    static let allowConsonantZFWJ = false
    static let quickStartConsonant = false
    static let quickEndConsonant = false
    static let rememberCode = true
    static let autoRestoreEnglishWord = true

    // MARK: - Restore & Pause
    static let restoreOnEscape = true
    static let restoreKeyCode = KeyCode.escape
    static let pauseKeyEnabled = false
    static let pauseKeyCode = KeyCode.leftOption
    static let pauseKeyName = "Option"

    // MARK: - Emoji Hotkey
    static let enableEmojiHotkey = true
    static let emojiHotkeyModifiers = NSEvent.ModifierFlags.command.rawValue
    static let emojiHotkeyKeyCode = KeyCode.eKey

    // MARK: - System
    static let runOnStartup = false
    static let performLayoutCompat = false
    static let showIconOnDock = false
    static let settingsWindowAlwaysOnTop = false
    static let safeMode = false
    static let enableLiquidGlassBackground = true
    static let settingsBackgroundOpacity = 1.0

    // MARK: - Hotkey
    static let switchKeyControl = true
    static let switchKeyOption = false
    static let switchKeyCommand = false
    static let switchKeyShift = true
    static let switchKeyFn = false
    static let switchKeyCode = KeyCode.noKey
    static let switchKeyName = "Không"
    static let beepOnModeSwitch = false

    // MARK: - Audio & Display
    static let beepVolume = 0.5
    static let menuBarIconSize = 18.0
    static let useVietnameseMenubarIcon = false

    // MARK: - Updates
    static let updateCheckInterval = 86400  // 1 day in seconds
    static let betaChannelEnabled = false
    static let autoInstallUpdates = true
}

// MARK: - Timing Constants

enum Timing {
    /// Debounce time for settings observers (milliseconds)
    static let settingsDebounce = 100

    /// Debounce time for audio sliders (milliseconds)
    static let audioSliderDebounce = 250

    /// Debounce time for hotkey changes (milliseconds)
    static let hotkeyDebounce = 10

    /// External settings observer debounce (seconds)
    static let externalSettingsDebounce = 0.1

    /// Login item status check interval (seconds)
    static let loginItemCheckInterval = 5.0

    /// Grace period for login item changes (seconds)
    static let loginItemGracePeriod = 10.0
}
