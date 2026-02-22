//
//  AppDelegate+SettingsBridge.swift
//  PHTV
//
//  Swift port of AppDelegate+SettingsBridge.mm.
//

import AppKit
import Foundation

private let phtvDefaultsKeySwitchKeyStatus = "SwitchKeyStatus"

private let phtvNotificationShowMacroTab = Notification.Name("ShowMacroTab")
private let phtvNotificationShowAboutTab = Notification.Name("ShowAboutTab")
private let phtvNotificationInputMethodChanged = Notification.Name("InputMethodChanged")
private let phtvNotificationCodeTableChanged = Notification.Name("CodeTableChanged")
private let phtvNotificationShowDockIcon = Notification.Name("PHTVShowDockIcon")
private let phtvNotificationCustomDictionaryUpdated = Notification.Name("CustomDictionaryUpdated")
private let phtvNotificationSettingsReset = Notification.Name("SettingsReset")
private let phtvNotificationAccessibilityPermissionLost = Notification.Name("AccessibilityPermissionLost")
private let phtvNotificationAccessibilityNeedsRelaunch = Notification.Name("AccessibilityNeedsRelaunch")

@MainActor private var phtvLastUpperCaseFirstCharSetting = -1

private func phtvSettingsBridgeLiveDebugEnabled() -> Bool {
    if let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"], !env.isEmpty {
        return env != "0"
    }
    if let stored = UserDefaults.standard.object(forKey: "PHTV_LIVE_DEBUG") as? NSNumber {
        return stored.intValue != 0
    }
    return false
}

private func phtvSettingsBridgeLiveLog(_ message: String) {
    guard phtvSettingsBridgeLiveDebugEnabled() else {
        return
    }
    NSLog("[PHTV Live] %@", message)
}

@MainActor extension AppDelegate {
    @objc func setupSwiftUIBridge() {
        phtvSettingsBridgeLiveLog("setupSwiftUIBridge registering observers")

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(onShowMacroTab(_:)),
                           name: phtvNotificationShowMacroTab,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(onShowAboutTab(_:)),
                           name: phtvNotificationShowAboutTab,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleInputMethodChanged(_:)),
                           name: phtvNotificationInputMethodChanged,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleCodeTableChanged(_:)),
                           name: phtvNotificationCodeTableChanged,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleShowDockIconNotification(_:)),
                           name: phtvNotificationShowDockIcon,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleCustomDictionaryUpdated(_:)),
                           name: phtvNotificationCustomDictionaryUpdated,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleSettingsReset(_:)),
                           name: phtvNotificationSettingsReset,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleAccessibilityRevoked),
                           name: phtvNotificationAccessibilityPermissionLost,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleAccessibilityNeedsRelaunch),
                           name: phtvNotificationAccessibilityNeedsRelaunch,
                           object: nil)
    }

    @objc func handleMenuBarIconSizeChanged(_ notification: Notification?) {
        let sizeValue = (notification?.object as? NSNumber)?.doubleValue
            ?? UserDefaults.standard.double(forKey: "vMenuBarIconSize")

        var size = CGFloat(sizeValue > 0 ? sizeValue : 12.0)
        size = min(max(size, 10.0), 28.0)

        statusBarFontSize = size
        fillData()
    }

    @objc func handleHotkeyChanged(_ notification: Notification?) {
        phtvSettingsBridgeLiveLog("received HotkeyChanged")
        guard let hotkey = notification?.object as? NSNumber else {
            return
        }

        let switchKeyStatus = hotkey.int32Value
        PHTVManager.setSwitchKeyStatus(switchKeyStatus)
        UserDefaults.standard.set(Int(switchKeyStatus), forKey: phtvDefaultsKeySwitchKeyStatus)
        fillData()

#if DEBUG
        let hasBeep = (Int(switchKeyStatus) & 0x8000) != 0
        NSLog("[SwiftUI] Hotkey changed to: 0x%X (beep=%@)", switchKeyStatus, hasBeep ? "YES" : "NO")
#endif
    }

    @objc func handleEmojiHotkeySettingsChanged(_ notification: Notification?) {
        _ = notification
        PHTVManager.loadEmojiHotkeySettingsFromDefaults()
        EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
        let snapshot = PHTVManager.runtimeSettingsSnapshot()

#if DEBUG
        let enabled = snapshot["enableEmojiHotkey"]?.intValue ?? 0
        let modifiers = snapshot["emojiHotkeyModifiers"]?.intValue ?? 0
        let keyCode = snapshot["emojiHotkeyKeyCode"]?.intValue ?? 0
        NSLog("[SwiftUI] Emoji hotkey changed: enabled=%d modifiers=0x%X keyCode=%d",
              enabled, modifiers, keyCode)
#endif
    }

    @objc func handleTCCDatabaseChanged(_ notification: Notification?) {
        NSLog("[TCC] TCC database change notification received in AppDelegate")
        NSLog("[TCC] userInfo: %@", String(describing: notification?.userInfo))

        PHTVManager.invalidatePermissionCache()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.checkAccessibilityStatus()
        }
    }

    @objc func handleSettingsChanged(_ notification: Notification?) {
        _ = notification
        phtvSettingsBridgeLiveLog("received PHTVSettingsChanged")

        let currentToken = PHTVManager.phtv_currentSettingsTokenFromUserDefaults()
        if currentToken == lastSettingsChangeToken {
            return
        }

        let old = PHTVManager.runtimeSettingsSnapshot()
        let settingsToken = PHTVManager.loadRuntimeSettingsFromUserDefaults()
        let new = PHTVManager.runtimeSettingsSnapshot()

        func changed(_ key: String) -> Bool {
            old[key]?.intValue != new[key]?.intValue
        }

        let justEnabledUppercase: Bool
        let newUpperCaseFirstChar = new["upperCaseFirstChar"]?.intValue ?? 0
        if phtvLastUpperCaseFirstCharSetting != -1 {
            justEnabledUppercase = (phtvLastUpperCaseFirstCharSetting == 0 && newUpperCaseFirstChar != 0)
        } else {
            justEnabledUppercase = false
        }

        let changed1 = changed("checkSpelling")
            || changed("useModernOrthography")
            || changed("quickTelex")

        let changed2 = changed("useMacro")
            || changed("useMacroInEnglishMode")
            || changed("autoCapsMacro")
            || changed("sendKeyStepByStep")
            || changed("useSmartSwitchKey")
            || changed("upperCaseFirstChar")
            || changed("allowConsonantZFWJ")
            || changed("quickStartConsonant")
            || changed("quickEndConsonant")
            || changed("rememberCode")
            || changed("performLayoutCompat")

        let changedRestorePause = changed("restoreOnEscape")
            || changed("customEscapeKey")
            || changed("pauseKeyEnabled")
            || changed("pauseKey")
            || changed("autoRestoreEnglishWord")

        let changedEmoji = changed("enableEmojiHotkey")
            || changed("emojiHotkeyModifiers")
            || changed("emojiHotkeyKeyCode")

        let changedDockVisibility = changed("showIconOnDock")
        let changedSessionSettings = changed1 || changed2 || changedRestorePause || changedEmoji
        let changedAny = changedSessionSettings || changedDockVisibility

        if !changedAny {
            lastSettingsChangeToken = settingsToken
            return
        }

        if changedSessionSettings {
            PHTVManager.syncSpellingSetting()
            PHTVManager.requestNewSession()
            if changedEmoji {
                EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
            }

            if justEnabledUppercase {
                // Request a fresh session already primes new typing state.
                _ = justEnabledUppercase
            }
        }

        if phtvSettingsBridgeLiveDebugEnabled() {
            let useMacro = new["useMacro"]?.intValue ?? 0
            phtvSettingsBridgeLiveLog(
                "settings loaded; changedGroup1=\(changed1 ? "YES" : "NO") changedGroup2=\(changed2 ? "YES" : "NO") changedRestorePause=\(changedRestorePause ? "YES" : "NO") changedEmoji=\(changedEmoji ? "YES" : "NO") changedDock=\(changedDockVisibility ? "YES" : "NO") useMacro=\(useMacro) upperCaseFirst=\(newUpperCaseFirstChar)"
            )
        }

        let oldSmartSwitch = old["useSmartSwitchKey"]?.intValue ?? 0
        let newSmartSwitch = new["useSmartSwitchKey"]?.intValue ?? 0
        if changedSessionSettings && oldSmartSwitch == 0 && newSmartSwitch != 0 && PHTVManager.isInited() {
            PHTVManager.notifyActiveAppChanged()
        }

        phtvLastUpperCaseFirstCharSetting = newUpperCaseFirstChar
        lastSettingsChangeToken = settingsToken

#if DEBUG
        if changedAny {
            let checkSpelling = new["checkSpelling"]?.intValue ?? 0
            let useMacro = new["useMacro"]?.intValue ?? 0
            let autoCapsMacro = new["autoCapsMacro"]?.intValue ?? 0
            let useMacroInEnglishMode = new["useMacroInEnglishMode"]?.intValue ?? 0
            let performLayoutCompat = new["performLayoutCompat"]?.intValue ?? 0
            let enabled = new["enableEmojiHotkey"]?.intValue ?? 0
            let modifiers = new["emojiHotkeyModifiers"]?.intValue ?? 0
            let keyCode = new["emojiHotkeyKeyCode"]?.intValue ?? 0

            NSLog("[SwiftUI] Settings reloaded from UserDefaults")
            NSLog("  - checkSpelling=%d", checkSpelling)
            NSLog("  - useMacro=%d, autoCapsMacro=%d, useMacroInEnglishMode=%d",
                  useMacro, autoCapsMacro, useMacroInEnglishMode)
            NSLog("  - performLayoutCompat=%d", performLayoutCompat)
            NSLog("  - emojiHotkey enabled=%d modifiers=0x%X keyCode=%d",
                  enabled, modifiers, keyCode)
        }
#endif

        if changedDockVisibility {
            DispatchQueue.main.async {
                if self.isSettingsWindowVisible() {
                    NSLog("[AppDelegate] Settings window open (verified), keeping dock icon visible")
                    return
                }
                let showOnDock = (new["showIconOnDock"]?.intValue ?? 0) != 0
                let policy: NSApplication.ActivationPolicy = showOnDock ? .regular : .accessory
                NSApp.setActivationPolicy(policy)
                if showOnDock {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    @objc func handleUserDefaultsDidChange(_ notification: Notification?) {
        _ = notification
        let now = CFAbsoluteTimeGetCurrent()
        if lastDefaultsApplyTime > 0 && (now - lastDefaultsApplyTime) < 0.10 {
            return
        }
        lastDefaultsApplyTime = now

        phtvSettingsBridgeLiveLog("received NSUserDefaultsDidChangeNotification")

        let defaults = UserDefaults.standard
        let currentSwitchKeyStatus = Int(PHTVManager.currentSwitchKeyStatus())
        let newSwitchKeyStatus: Int
        if defaults.object(forKey: phtvDefaultsKeySwitchKeyStatus) == nil {
            newSwitchKeyStatus = currentSwitchKeyStatus
        } else {
            newSwitchKeyStatus = defaults.integer(forKey: phtvDefaultsKeySwitchKeyStatus)
        }

        if newSwitchKeyStatus != currentSwitchKeyStatus {
            PHTVManager.setSwitchKeyStatus(Int32(newSwitchKeyStatus))
            fillData()
            phtvSettingsBridgeLiveLog(String(format: "applied SwitchKeyStatus from defaults: 0x%X", newSwitchKeyStatus))
        }

        handleSettingsChanged(nil)
    }
}
