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
    static let sendKeyStepByStep = "SendKeyStepByStep"
    static let useMacro = "UseMacro"
    static let useMacroInEnglishMode = "UseMacroInEnglishMode"
    static let autoCapsMacro = "vAutoCapsMacro"
    static let macroList = "macroList"
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
    static let upperCaseExcludedApps = "UpperCaseExcludedApps"
    static let klipyCustomerID = "KlipyCustomerID"

    // MARK: - Sparkle Updates
    static let updateCheckInterval = "SUScheduledCheckInterval"
    static let sparkleBetaChannel = "SUEnableBetaChannel"
    static let autoInstallUpdates = "vAutoInstallUpdates"

    // MARK: - Debug
    static let liveDebug = "PHTV_LIVE_DEBUG"
    static let includeSystemInfo = "vIncludeSystemInfo"
    static let includeLogs = "vIncludeLogs"
    static let includeCrashLogs = "vIncludeCrashLogs"

    // MARK: - Onboarding
    static let onboardingCompleted = "PHTV_OnboardingCompleted"
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
    static let toggleEnabled = NSNotification.Name("ToggleEnabled")
    static let hotkeyChanged = NSNotification.Name("HotkeyChanged")
    static let settingsResetToDefaults = NSNotification.Name("SettingsResetToDefaults")
    static let macrosUpdated = NSNotification.Name("MacrosUpdated")
    static let customDictionaryUpdated = NSNotification.Name("CustomDictionaryUpdated")

    // MARK: - App Lists
    static let excludedAppsChanged = NSNotification.Name("ExcludedAppsChanged")
    static let sendKeyStepByStepAppsChanged = NSNotification.Name("SendKeyStepByStepAppsChanged")
    static let upperCaseExcludedAppsChanged = NSNotification.Name("UpperCaseExcludedAppsChanged")

    // MARK: - Emoji Hotkey
    static let emojiHotkeySettingsChanged = NSNotification.Name("EmojiHotkeySettingsChanged")

    // MARK: - System
    static let accessibilityStatusChanged = NSNotification.Name("AccessibilityStatusChanged")
    static let runOnStartupChanged = NSNotification.Name("RunOnStartupChanged")
    static let applicationWillTerminate = NSNotification.Name("ApplicationWillTerminate")
    static let showSettings = NSNotification.Name("ShowSettings")
    static let createSettingsWindow = NSNotification.Name("CreateSettingsWindow")
    static let phtvShowDockIcon = NSNotification.Name("PHTVShowDockIcon")

    // MARK: - UI Updates
    static let menuBarIconSizeChanged = NSNotification.Name("MenuBarIconSizeChanged")
    static let menuBarIconPreferenceChanged = NSNotification.Name("MenuBarIconPreferenceChanged")
    static let showAboutTab = NSNotification.Name("ShowAboutTab")
    static let showMacroTab = NSNotification.Name("ShowMacroTab")
    static let showOnboarding = NSNotification.Name("ShowOnboarding")
    static let showConvertToolSheet = NSNotification.Name("ShowConvertToolSheet")
    static let openConvertToolSheet = NSNotification.Name("OpenConvertToolSheet")
    static let showConvertTool = NSNotification.Name("ShowConvertTool")
    static let openConvertTool = NSNotification.Name("OpenConvertTool")
    static let showAbout = NSNotification.Name("ShowAbout")

    // MARK: - Updates
    static let checkForUpdatesResponse = NSNotification.Name("CheckForUpdatesResponse")
    static let updateCheckFrequencyChanged = NSNotification.Name("UpdateCheckFrequencyChanged")
    static let sparkleShowUpdateBanner = NSNotification.Name("SparkleShowUpdateBanner")
    static let sparkleManualCheck = NSNotification.Name("SparkleManualCheck")
    static let sparkleInstallUpdate = NSNotification.Name("SparkleInstallUpdate")
}

// MARK: - Notification UserInfo Keys

enum NotificationUserInfoKey {
    static let visible = "visible"
    static let forceFront = "forceFront"
    static let enabled = "enabled"
    static let macroId = "macroId"
    static let action = "action"
}

enum MacroUpdateAction {
    static let added = "added"
    static let edited = "edited"
}

enum EventSourceMarker {
    static let phtv: Int64 = 0x5048_5456 // "PHTV"
}

enum EngineBitMask {
    static let caps: UInt32 = 0x0001_0000
    static let charCode: UInt32 = 0x0200_0000
    static let pureCharacter: UInt32 = 0x8000_0000
}

enum EnginePackedData {
    static let unicodeCompoundMarks: [UInt16] = [0x0301, 0x0300, 0x0309, 0x0303, 0x0323]

    static func lowByte(_ value: UInt32) -> UInt16 {
        UInt16(truncatingIfNeeded: value & 0x00FF)
    }

    static func highByte(_ value: UInt32) -> UInt16 {
        UInt16(truncatingIfNeeded: (value >> 8) & 0x00FF)
    }

    static func unicodeCompoundMark(at index: Int32) -> UInt16 {
        let safeIndex = Int(index)
        guard unicodeCompoundMarks.indices.contains(safeIndex) else {
            return 0
        }
        return unicodeCompoundMarks[safeIndex]
    }
}

enum EngineSignalCode {
    static let doNothing: Int32 = 0
    static let willProcess: Int32 = 1
    static let restore: Int32 = 3
    static let replaceMacro: Int32 = 4
    static let restoreAndStartNewSession: Int32 = 5
    static let maxBuffer: Int32 = 32
}

// MARK: - Key Codes

enum KeyCode {
    // MARK: - Special Keys
    static let noKey: UInt16 = 0xFE  // Modifier-only mode (no physical key)
    static let keyMask = 0x00FF
    static let tab: UInt16 = 48
    static let delete: UInt16 = 51
    static let escape: UInt16 = 53
    static let enter: UInt16 = 76
    static let returnKey: UInt16 = 36
    static let leftCommand: UInt16 = 55
    static let rightCommand: UInt16 = 54
    static let leftControl: UInt16 = 59
    static let rightControl: UInt16 = 62
    static let leftOption: UInt16 = 58
    static let rightOption: UInt16 = 61
    static let space: UInt16 = 49
    static let slash: UInt16 = 44
    static let eKey: UInt16 = 14
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
    static let home: UInt16 = 115
    static let pageUp: UInt16 = 116
    static let end: UInt16 = 119
    static let pageDown: UInt16 = 121
    static let modifierOnlyDisplayName = "Không"

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

    static func isModifierOnly(_ keyCode: UInt16) -> Bool {
        keyCode == noKey
    }

    static func name(for keyCode: UInt16) -> String {
        if isModifierOnly(keyCode) {
            return modifierOnlyDisplayName
        }
        return keyNames[keyCode] ?? "Key \(keyCode)"
    }
}

enum HotkeyFormatter {
    static func switchHotkeyString(
        control: Bool,
        option: Bool,
        shift: Bool,
        command: Bool,
        fn: Bool,
        keyCode: UInt16,
        keyName: String
    ) -> String {
        var parts: [String] = []
        if fn { parts.append("fn") }
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        if !KeyCode.isModifierOnly(keyCode) { parts.append(keyName) }
        return parts.isEmpty ? "Chưa đặt" : parts.joined()
    }
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
    static let sendKeyStepByStep = false
    static let useMacro = true
    static let useMacroInEnglishMode = false
    static let autoCapsMacro = false
    static let useSmartSwitchKey = true
    static let upperCaseFirstChar = false
    static let allowConsonantZFWJ = true
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
    static let settingsWindowAlwaysOnTop = true
    static let safeMode = false

    // MARK: - Hotkey
    static let switchKeyControl = true
    static let switchKeyOption = false
    static let switchKeyCommand = false
    static let switchKeyShift = true
    static let switchKeyFn = false
    static let switchKeyCode = KeyCode.noKey
    static let switchKeyName = KeyCode.modifierOnlyDisplayName
    static let beepOnModeSwitch = false
    static var defaultSwitchKeyStatus: Int {
        var status = Int(switchKeyCode)
        if switchKeyControl { status |= KeyCode.controlMask }
        if switchKeyOption { status |= KeyCode.optionMask }
        if switchKeyCommand { status |= KeyCode.commandMask }
        if switchKeyShift { status |= KeyCode.shiftMask }
        if switchKeyFn { status |= KeyCode.fnMask }
        if beepOnModeSwitch { status |= KeyCode.beepMask }
        return status
    }

    // MARK: - Audio & Display
    static let beepVolume = 0.5
    static let menuBarIconSize = 18.0
    static let useVietnameseMenubarIcon = false

    // MARK: - Updates
    static let updateCheckInterval = 86400  // 1 day in seconds

    // MARK: - Bug Report
    static let includeSystemInfo = true
    static let includeLogs = false
    static let includeCrashLogs = true
}

// MARK: - UserDefaults Helpers

extension UserDefaults {
    /// Reads a Bool with explicit fallback when the key is missing.
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard let value = object(forKey: key) else {
            return defaultValue
        }
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }
        return defaultValue
    }

    /// Reads an Int with explicit fallback when the key is missing.
    func integer(forKey key: String, default defaultValue: Int) -> Int {
        guard let value = object(forKey: key) else {
            return defaultValue
        }
        if let intValue = value as? Int {
            return intValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue
        }
        return defaultValue
    }

    /// Reads a Double with explicit fallback when the key is missing.
    func double(forKey key: String, default defaultValue: Double) -> Double {
        guard let value = object(forKey: key) else {
            return defaultValue
        }
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.doubleValue
        }
        return defaultValue
    }

    /// Always use stable update channel and auto-install updates.
    func enforceStableUpdateChannel() {
        removeObject(forKey: UserDefaultsKey.sparkleBetaChannel)
        set(true, forKey: UserDefaultsKey.autoInstallUpdates)
    }
}

// MARK: - Settings Bootstrap

@objcMembers
final class SettingsBootstrap: NSObject {
    /// Registers all default settings used by both Swift and Objective-C layers.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: registrationDefaults())
    }

    private static func registrationDefaults() -> [String: Any] {
        [
            UserDefaultsKey.inputMethod: 1,
            UserDefaultsKey.inputType: Defaults.inputMethod.toIndex(),
            UserDefaultsKey.codeTable: Defaults.codeTable.toIndex(),
            UserDefaultsKey.spelling: Defaults.checkSpelling,
            UserDefaultsKey.modernOrthography: Defaults.useModernOrthography,
            UserDefaultsKey.quickTelex: Defaults.quickTelex,
            UserDefaultsKey.useMacro: Defaults.useMacro,
            UserDefaultsKey.useMacroInEnglishMode: Defaults.useMacroInEnglishMode,
            UserDefaultsKey.autoCapsMacro: Defaults.autoCapsMacro,
            UserDefaultsKey.sendKeyStepByStep: Defaults.sendKeyStepByStep,
            UserDefaultsKey.useSmartSwitchKey: Defaults.useSmartSwitchKey,
            UserDefaultsKey.upperCaseFirstChar: Defaults.upperCaseFirstChar,
            UserDefaultsKey.allowConsonantZFWJ: Defaults.allowConsonantZFWJ,
            UserDefaultsKey.quickStartConsonant: Defaults.quickStartConsonant,
            UserDefaultsKey.quickEndConsonant: Defaults.quickEndConsonant,
            UserDefaultsKey.rememberCode: Defaults.rememberCode,
            UserDefaultsKey.autoRestoreEnglishWord: Defaults.autoRestoreEnglishWord,
            UserDefaultsKey.restoreOnEscape: Defaults.restoreOnEscape,
            UserDefaultsKey.customEscapeKey: Int(Defaults.restoreKeyCode),
            UserDefaultsKey.pauseKeyEnabled: Defaults.pauseKeyEnabled,
            UserDefaultsKey.pauseKey: Int(Defaults.pauseKeyCode),
            UserDefaultsKey.pauseKeyName: Defaults.pauseKeyName,
            UserDefaultsKey.switchKeyStatus: Defaults.defaultSwitchKeyStatus,
            UserDefaultsKey.beepOnModeSwitch: Defaults.beepOnModeSwitch,
            UserDefaultsKey.beepVolume: Defaults.beepVolume,
            UserDefaultsKey.menuBarIconSize: Defaults.menuBarIconSize,
            UserDefaultsKey.useVietnameseMenubarIcon: Defaults.useVietnameseMenubarIcon,
            UserDefaultsKey.showIconOnDock: Defaults.showIconOnDock,
            UserDefaultsKey.performLayoutCompat: Defaults.performLayoutCompat,
            UserDefaultsKey.settingsWindowAlwaysOnTop: Defaults.settingsWindowAlwaysOnTop,
            UserDefaultsKey.safeMode: Defaults.safeMode,
            UserDefaultsKey.enableEmojiHotkey: Defaults.enableEmojiHotkey,
            UserDefaultsKey.emojiHotkeyModifiers: Int(Defaults.emojiHotkeyModifiers),
            UserDefaultsKey.emojiHotkeyKeyCode: Int(Defaults.emojiHotkeyKeyCode),
            UserDefaultsKey.runOnStartup: Defaults.runOnStartup,
            UserDefaultsKey.runOnStartupLegacy: 0,
            UserDefaultsKey.updateCheckInterval: Defaults.updateCheckInterval,
            UserDefaultsKey.includeSystemInfo: Defaults.includeSystemInfo,
            UserDefaultsKey.includeLogs: Defaults.includeLogs,
            UserDefaultsKey.includeCrashLogs: Defaults.includeCrashLogs,
            UserDefaultsKey.autoInstallUpdates: true,
            "FreeMark": 0,
            "FixRecommendBrowser": 1,
            "vTempOffSpelling": 0,
            "vOtherLanguage": 1,
            "vTempOffPHTV": 0,
            "GrayIcon": 1
        ]
    }
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
