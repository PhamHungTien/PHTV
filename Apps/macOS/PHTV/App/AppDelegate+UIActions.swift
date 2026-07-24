//
//  AppDelegate+UIActions.swift
//  PHTV
//
//  UI action routing and reset handling.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

private let phtvDefaultsKeyNonFirstTime = "NonFirstTime"
private let phtvNotificationSettingsResetComplete = NotificationName.settingsResetComplete
private let phtvNotificationShowSettings = NotificationName.showSettings
private let phtvNotificationShowMacroTab = NotificationName.showMacroTab
private let phtvNotificationShowAboutTab = NotificationName.showAboutTab

@MainActor @objc extension AppDelegate {
    func handleSettingsReset(_ notification: Notification?) {
        _ = notification

        NotificationCenter.default.post(name: phtvNotificationSettingsResetComplete, object: nil)

        #if DEBUG
        NSLog("[Settings Reset] Reset complete, UI will refresh")
        #endif
    }

    func onShowMacroTab(_ notification: Notification?) {
        _ = notification
        onControlPanelSelected()
    }

    func onShowAboutTab(_ notification: Notification?) {
        _ = notification
        onControlPanelSelected()
    }

    func onQuickConvert() {
        if PHTVManager.quickConvert() {
            // Legacy behavior: show success alert only when this flag is true.
            if UserDefaults.standard.bool(forKey: UserDefaultsKey.convertToolDontAlertWhenCompleted) {
                PHTVManager.showMessage(nil,
                                        message: "Chuyển mã thành công!",
                                        subMsg: "Kết quả đã được lưu trong clipboard.")
            }
        } else {
            PHTVManager.showMessage(nil,
                                    message: "Không có dữ liệu trong clipboard!",
                                    subMsg: "Hãy sao chép một đoạn text để chuyển đổi!")
        }
    }

    func onEmojiHotkeyTriggered() {
        EmojiHotkeyBridge.openEmojiPicker()
    }

    func onControlPanelSelected() {
        setDockIconVisible(true)

        let defaults = UserDefaults.standard
        if defaults.integer(forKey: phtvDefaultsKeyNonFirstTime) == 0 {
            defaults.set(1, forKey: phtvDefaultsKeyNonFirstTime)
            NSLog("Marking NonFirstTime after user opened settings")
        }

        NSLog("[AppDelegate] Posting ShowSettings notification")
        NotificationCenter.default.post(name: phtvNotificationShowSettings, object: nil)
    }

    func onMacroSelected() {
        NotificationCenter.default.post(name: phtvNotificationShowMacroTab, object: nil)
    }

    func onAboutSelected() {
        NotificationCenter.default.post(name: phtvNotificationShowAboutTab, object: nil)
    }

    func onSwitchLanguage() {
        onInputMethodSelected()
    }
}
