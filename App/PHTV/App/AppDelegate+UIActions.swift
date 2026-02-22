//
//  AppDelegate+UIActions.swift
//  PHTV
//
//  Swift port of AppDelegate+UIActions.mm.
//

import Foundation

private let phtvDefaultsKeyNonFirstTime = "NonFirstTime"
private let phtvNotificationSettingsResetComplete = Notification.Name("SettingsResetComplete")
private let phtvNotificationShowSettings = Notification.Name("ShowSettings")
private let phtvNotificationShowMacroTab = Notification.Name("ShowMacroTab")
private let phtvNotificationShowAboutTab = Notification.Name("ShowAboutTab")
private let convertToolDontAlertWhenCompletedKey = "convertToolDontAlertWhenCompleted"

@MainActor @objc extension AppDelegate {
    func handleSettingsReset(_ notification: Notification?) {
        _ = notification

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: phtvNotificationSettingsResetComplete, object: nil)

            #if DEBUG
            NSLog("[Settings Reset] Reset complete, UI will refresh")
            #endif
        }
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
            if UserDefaults.standard.bool(forKey: convertToolDontAlertWhenCompletedKey) {
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
        DispatchQueue.main.async {
            EmojiHotkeyBridge.openEmojiPicker()
        }
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
