//
//  AppDelegate+SettingsActions.swift
//  PHTV
//
//  Swift port of AppDelegate+SettingsActions.mm.
//

import Foundation

private let phtvNotificationSettingsChanged = Notification.Name("PHTVSettingsChanged")

@MainActor @objc extension AppDelegate {
    func toggleSpellCheck(_ sender: Any?) {
        _ = sender
        _ = PHTVManager.toggleSpellCheckSetting()
        fillData()
        NotificationCenter.default.post(name: phtvNotificationSettingsChanged, object: nil)
    }

    func toggleAllowConsonantZFWJ(_ sender: Any?) {
        _ = sender
        _ = PHTVManager.toggleAllowConsonantZFWJSetting()
        fillData()
        NotificationCenter.default.post(name: phtvNotificationSettingsChanged, object: nil)
    }

    func toggleModernOrthography(_ sender: Any?) {
        _ = sender
        _ = PHTVManager.toggleModernOrthographySetting()
        fillData()
        NotificationCenter.default.post(name: phtvNotificationSettingsChanged, object: nil)
    }

    func toggleQuickTelex(_ sender: Any?) {
        _ = sender
        _ = PHTVManager.toggleQuickTelexSetting()
        fillData()
        NotificationCenter.default.post(name: phtvNotificationSettingsChanged, object: nil)
    }

    func toggleUpperCaseFirstChar(_ sender: Any?) {
        _ = sender
        _ = PHTVManager.toggleUpperCaseFirstCharSetting()
        fillData()
        NotificationCenter.default.post(name: phtvNotificationSettingsChanged, object: nil)
    }

    func toggleAutoRestoreEnglishWord(_ sender: Any?) {
        _ = sender
        _ = PHTVManager.toggleAutoRestoreEnglishWordSetting()
        fillData()
        NotificationCenter.default.post(name: phtvNotificationSettingsChanged, object: nil)
    }
}
