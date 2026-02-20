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
        if let delegate = GetAppDelegateInstance() {
            return delegate
        }
        return NSApp.delegate as? AppDelegate
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
            DispatchQueue.global(qos: .default).async {
                PHTVManager.notifyInputMethodChanged()
            }
        }

#if DEBUG
        NSLog("[Hotkey] Fallback language toggle applied: %d -> %d", currentLanguage, targetLanguage)
#endif
    }

    @objc class func handleInputMethodChangeFromHotkey() {
        let action = {
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
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }

    @objc class func refreshAfterSmartSwitchLanguageChange(_ language: Int32) {
        let action = {
            guard let delegate = resolveAppDelegate() else {
                return
            }
            delegate.fillData()
            NotificationCenter.default.post(
                name: NSNotification.Name("LanguageChangedFromSmartSwitch"),
                object: NSNumber(value: language)
            )
        }
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }

    @objc class func refreshAfterSmartSwitchCodeTableChange() {
        let action = {
            guard let delegate = resolveAppDelegate() else {
                return
            }
            delegate.fillData()
        }
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }

    @objc class func triggerQuickConvert() {
        let action = {
            guard let delegate = resolveAppDelegate() else {
                return
            }
            delegate.onQuickConvert()
        }
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }

    @objc class func triggerEmojiHotkey() {
        let action = {
            guard let delegate = resolveAppDelegate() else {
                return
            }
            delegate.onEmojiHotkeyTriggered()
        }
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }
}
