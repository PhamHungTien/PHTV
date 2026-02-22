//
//  PHTVRuntimeUIBridgeService.swift
//  PHTV
//
//  Bridges runtime callbacks from the core event pipeline to AppDelegate/UI updates.
//

import AppKit
import Foundation

@MainActor
@objcMembers
final class PHTVRuntimeUIBridgeService: NSObject {
    private static let languageChangedNotification = Notification.Name("LanguageChangedFromBackend")
    private static let inputMethodDefaultsKey = "InputMethod"

    private class func resolveAppDelegate() -> AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    private class func fallbackQuickConvertFromHotkey() {
        _ = PHTVManager.quickConvert()
#if DEBUG
        NSLog("[Hotkey] Fallback quick-convert executed without AppDelegate")
#endif
    }

    private class func fallbackEmojiPickerFromHotkey() {
        EmojiHotkeyBridge.openEmojiPicker()
#if DEBUG
        NSLog("[Hotkey] Fallback emoji picker open executed without AppDelegate")
#endif
    }

    private class func forceToggleLanguageFromHotkey() {
        let currentLanguage = PHTVManager.currentLanguage()
        let targetLanguage: Int32 = (currentLanguage == 0) ? 1 : 0

        PHTVManager.setCurrentLanguage(targetLanguage)
        UserDefaults.standard.set(Int(targetLanguage), forKey: inputMethodDefaultsKey)
        PHTVManager.requestNewSession()

        resolveAppDelegate()?.fillData()
        NotificationCenter.default.post(name: languageChangedNotification,
                                        object: NSNumber(value: targetLanguage))

        if PHTVManager.isSmartSwitchKeyEnabled() {
            Task.detached(priority: .utility) {
                PHTVManager.notifyInputMethodChanged()
            }
        }

#if DEBUG
        NSLog("[Hotkey] Fallback language toggle applied: %d -> %d", currentLanguage, targetLanguage)
#endif
    }

    @objc class func handleInputMethodChangeFromHotkey() {
        guard let delegate = resolveAppDelegate() else {
            forceToggleLanguageFromHotkey()
            return
        }
        let before = PHTVManager.currentLanguage()
        delegate.onImputMethodChanged(true)
        let after = PHTVManager.currentLanguage()
        if after == before {
            forceToggleLanguageFromHotkey()
        }
    }

    @objc class func refreshAfterSmartSwitchLanguageChange(_ language: Int32) {
        guard let delegate = resolveAppDelegate() else {
            return
        }
        delegate.fillData()
        NotificationCenter.default.post(
            name: NSNotification.Name("LanguageChangedFromSmartSwitch"),
            object: NSNumber(value: language)
        )
    }

    @objc class func refreshAfterSmartSwitchCodeTableChange() {
        guard let delegate = resolveAppDelegate() else {
            return
        }
        delegate.fillData()
    }

    @objc class func triggerQuickConvert() {
        guard let delegate = resolveAppDelegate() else {
            fallbackQuickConvertFromHotkey()
            return
        }
        delegate.onQuickConvert()
    }

    @objc class func triggerEmojiHotkey() {
        guard let delegate = resolveAppDelegate() else {
            fallbackEmojiPickerFromHotkey()
            return
        }
        delegate.onEmojiHotkeyTriggered()
    }

    @objc class func handleKeyDownHotkeyAction(_ action: Int32) -> Bool {
        guard let keyAction = PHTVKeyDownHotkeyAction(rawValue: action) else {
            return false
        }

        switch keyAction {
        case .switchLanguage:
            handleInputMethodChangeFromHotkey()
            return true
        case .quickConvert:
            triggerQuickConvert()
            return true
        case .emojiPicker:
            triggerEmojiHotkey()
            return true
        case .none, .clearStaleModifiers:
            return false
        }
    }

    @objc(handleKeyDownHotkeyActionFromRuntime:)
    nonisolated class func handleKeyDownHotkeyActionFromRuntime(_ action: Int32) -> Bool {
        guard let keyAction = PHTVKeyDownHotkeyAction(rawValue: action) else {
            return false
        }

        switch keyAction {
        case .switchLanguage:
            Task { @MainActor in
                handleInputMethodChangeFromHotkey()
            }
            return true
        case .quickConvert:
            Task { @MainActor in
                triggerQuickConvert()
            }
            return true
        case .emojiPicker:
            Task { @MainActor in
                triggerEmojiHotkey()
            }
            return true
        case .none, .clearStaleModifiers:
            return false
        }
    }

    @objc class func handleModifierReleaseHotkeyAction(_ action: Int32) -> Bool {
        guard let releaseAction = PHTVModifierReleaseAction(rawValue: action) else {
            return false
        }

        switch releaseAction {
        case .switchLanguage:
            handleInputMethodChangeFromHotkey()
            return true
        case .quickConvert:
            triggerQuickConvert()
            return true
        case .emojiPicker:
            triggerEmojiHotkey()
            return true
        case .none, .tempOffSpelling, .tempOffEngine:
            return false
        }
    }

    @objc(handleModifierReleaseHotkeyActionFromRuntime:)
    nonisolated class func handleModifierReleaseHotkeyActionFromRuntime(_ action: Int32) -> Bool {
        guard let releaseAction = PHTVModifierReleaseAction(rawValue: action) else {
            return false
        }

        switch releaseAction {
        case .switchLanguage:
            Task { @MainActor in
                handleInputMethodChangeFromHotkey()
            }
            return true
        case .quickConvert:
            Task { @MainActor in
                triggerQuickConvert()
            }
            return true
        case .emojiPicker:
            Task { @MainActor in
                triggerEmojiHotkey()
            }
            return true
        case .none, .tempOffSpelling, .tempOffEngine:
            return false
        }
    }
}
