//
//  AppDelegate+SettingsBridge.swift
//  PHTV
//
//  Settings bridge and coordination helpers.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation

private let phtvDefaultsKeySwitchKeyStatus = UserDefaultsKey.switchKeyStatus
private let phtvDefaultsKeyConvertToolHotKey = UserDefaultsKey.convertToolHotKey

private let phtvNotificationShowMacroTab = NotificationName.showMacroTab
private let phtvNotificationShowAboutTab = NotificationName.showAboutTab
private let phtvNotificationInputMethodChanged = NotificationName.inputMethodChanged
private let phtvNotificationCodeTableChanged = NotificationName.codeTableChanged
private let phtvNotificationShowDockIcon = NotificationName.phtvShowDockIcon
private let phtvNotificationCustomDictionaryUpdated = NotificationName.customDictionaryUpdated
private let phtvNotificationSettingsReset = NotificationName.settingsReset
private let phtvNotificationSettingsResetToDefaults = NotificationName.settingsResetToDefaults
private let phtvNotificationAccessibilityPermissionLost = Notification.Name("AccessibilityPermissionLost")

@MainActor private var phtvLastUpperCaseFirstCharSetting = -1

private func phtvSettingsBridgeLiveDebugEnabled() -> Bool {
    if let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"], !env.isEmpty {
        return env != "0"
    }
    if let stored = UserDefaults.standard.object(forKey: UserDefaultsKey.liveDebug) as? NSNumber {
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
        settingsBridgeNotificationTasks.forEach { $0.cancel() }
        settingsBridgeNotificationTasks = [
            makeNotificationTask(center: center, name: phtvNotificationShowMacroTab) { appDelegate, notification in
                appDelegate.onShowMacroTab(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationShowAboutTab) { appDelegate, notification in
                appDelegate.onShowAboutTab(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationInputMethodChanged) { appDelegate, notification in
                appDelegate.handleInputMethodChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationCodeTableChanged) { appDelegate, notification in
                appDelegate.handleCodeTableChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationShowDockIcon) { appDelegate, notification in
                appDelegate.handleShowDockIconNotification(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationCustomDictionaryUpdated) { appDelegate, notification in
                appDelegate.handleCustomDictionaryUpdated(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationSettingsReset) { appDelegate, notification in
                appDelegate.handleSettingsReset(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationSettingsResetToDefaults) { appDelegate, notification in
                appDelegate.handleSettingsReset(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationAccessibilityPermissionLost) { appDelegate, _ in
                appDelegate.handleAccessibilityRevoked()
            }
        ]
    }

    @objc func handleHotkeyChanged(_ notification: Notification?) {
        phtvSettingsBridgeLiveLog("received HotkeyChanged")
        guard let hotkey = notification?.object as? NSNumber else {
            return
        }

        let switchKeyStatus = hotkey.int32Value
        let currentSwitchKeyStatus = PHTVManager.currentSwitchKeyStatus()
        let storedSwitchKeyStatus = Int32(
            UserDefaults.standard.integer(
                forKey: phtvDefaultsKeySwitchKeyStatus,
                default: Defaults.defaultSwitchKeyStatus
            )
        )
        guard switchKeyStatus != currentSwitchKeyStatus || switchKeyStatus != storedSwitchKeyStatus else {
            phtvSettingsBridgeLiveLog(String(format: "ignored duplicate HotkeyChanged: 0x%X", switchKeyStatus))
            return
        }

        PHTVManager.setSwitchKeyStatus(switchKeyStatus)
        UserDefaults.standard.set(Int(switchKeyStatus), forKey: phtvDefaultsKeySwitchKeyStatus)
        fillData()
        runHotkeyHealthCheck(reason: "switch-hotkey-changed")

#if DEBUG
        let hasBeep = (Int(switchKeyStatus) & 0x8000) != 0
        NSLog("[SwiftUI] Hotkey changed to: 0x%X (beep=%@)", switchKeyStatus, hasBeep ? "YES" : "NO")
#endif
    }

    @objc func handleEmojiHotkeySettingsChanged(_ notification: Notification?) {
        _ = notification
        PHTVManager.loadEmojiHotkeySettingsFromDefaults()
        EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
        runHotkeyHealthCheck(reason: "emoji-hotkey-changed")
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
#if DEBUG
        NSLog("[TCC] userInfo: %@", String(describing: notification?.userInfo))
#endif

        PHTVManager.invalidatePermissionCache()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
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

        let reloadResult = reloadRuntimeSettingsFromUserDefaults()
        let old = reloadResult.oldSnapshot
        let new = reloadResult.newSnapshot
        let settingsToken = reloadResult.token

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
            || changed("autoRestoreEnglishWordMode")
            || changed("restoreIfWrongSpelling")

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
        let oldRememberCode = old["rememberCode"]?.intValue ?? 0
        let newRememberCode = new["rememberCode"]?.intValue ?? 0
        let shouldReapplyFrontmostAppContext = (oldSmartSwitch == 0 && newSmartSwitch != 0)
            || (oldRememberCode == 0 && newRememberCode != 0)
        if changedSessionSettings && shouldReapplyFrontmostAppContext && PHTVManager.isInited() {
            syncCurrentFrontmostAppContext(reason: "settings-enabled-smart-switch-or-remember-code")
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

    @objc func handleUserDefaultsDidChange(_ notification: Notification?) {
        _ = notification
        let now = CFAbsoluteTimeGetCurrent()
        if lastDefaultsApplyTime > 0 && (now - lastDefaultsApplyTime) < 0.10 {
            return
        }
        lastDefaultsApplyTime = now

        phtvSettingsBridgeLiveLog("received NSUserDefaultsDidChangeNotification")

        let defaults = UserDefaults.standard
        let newConvertToolHotkeyValue: Int? = {
            guard defaults.object(forKey: phtvDefaultsKeyConvertToolHotKey) != nil else {
                return nil
            }
            return defaults.integer(forKey: phtvDefaultsKeyConvertToolHotKey)
        }()
        if newConvertToolHotkeyValue != lastConvertToolHotkeyDefaultsValue {
            lastConvertToolHotkeyDefaultsValue = newConvertToolHotkeyValue
            PHTVConvertToolHotkeyService.invalidateCache()
        }

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
        refreshMacrosIfSystemTextReplacementsChanged(resetSession: true)
    }
}
