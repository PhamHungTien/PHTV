//
//  AppDelegate+LoginItem.swift
//  PHTV
//
//  Swift port of AppDelegate+LoginItem.mm.
//

import AppKit
import Foundation

@MainActor @objc extension AppDelegate {
    @objc(syncRunOnStartupStatusWithFirstLaunch:)
    func syncRunOnStartupStatus(withFirstLaunch isFirstLaunch: Bool) {
        let defaults = UserDefaults.standard
        let savedEnabled = defaults.bool(forKey: UserDefaultsKey.runOnStartup) ||
            defaults.integer(forKey: UserDefaultsKey.runOnStartupLegacy) == 1

        let loginItemService = LoginItemService.shared
        let currentStatus = loginItemService.status
        let actuallyEnabled = loginItemService.isEnabled

        NSLog(
            "[LoginItem] Startup sync - Actual: %d, Saved: %d, Status: %ld",
            actuallyEnabled,
            savedEnabled,
            currentStatus.rawValue
        )

        if isFirstLaunch {
            NSLog("[LoginItem] First launch detected - enabling Launch at Login")
            setRunOnStartup(true)
            return
        }

        if actuallyEnabled != savedEnabled {
            if savedEnabled && !actuallyEnabled {
                NSLog("[LoginItem] Status mismatch - user setting ON but service is OFF, syncing to OFF")
                applyRunOnStartupState(enabled: false)
            } else if !savedEnabled && actuallyEnabled {
                NSLog("[LoginItem] Status mismatch - user setting OFF but service is ON, retrying disable")
                setRunOnStartup(false)
            }
        } else {
            NSLog("[LoginItem] ✅ Status consistent: %@", actuallyEnabled ? "ENABLED" : "DISABLED")
        }
    }

    @objc(setRunOnStartup:)
    func setRunOnStartup(_ val: Bool) {
        let loginItemService = LoginItemService.shared
        NSLog("[LoginItem] Current SMAppService status: %ld", loginItemService.status.rawValue)

        switch loginItemService.setEnabled(val) {
        case .enabled:
            NSLog("[LoginItem] ✅ Launch at Login enabled")
            applyRunOnStartupState(enabled: true)
        case .disabled:
            NSLog("[LoginItem] ✅ Launch at Login disabled")
            applyRunOnStartupState(enabled: false)
        case .requiresApproval:
            NSLog("[LoginItem] ⚠️ Launch at Login requires user approval in System Settings")
            applyRunOnStartupState(enabled: false)
            if val {
                presentLoginItemApprovalPrompt()
            }
        case .failed(let error):
            NSLog("[LoginItem] ❌ Failed to update Launch at Login")
            NSLog("   Error: %@", error.localizedDescription)
            NSLog("   Domain: %@, Code: %ld", error.domain, error.code)
            if !error.userInfo.isEmpty {
                NSLog("   UserInfo: %@", error.userInfo)
            }
            applyRunOnStartupState(enabled: loginItemService.isEnabled)
        }
    }

    @objc(toggleStartupItem:)
    func toggleStartupItem(_ sender: NSMenuItem) {
        _ = sender

        let currentValue = UserDefaults.standard.bool(forKey: UserDefaultsKey.runOnStartup)
        let newValue = !currentValue

        setRunOnStartup(newValue)
        fillData()

        let message = newValue
            ? "✅ PHTV sẽ tự động khởi động cùng hệ thống"
            : "❌ Đã tắt khởi động cùng hệ thống"
        NSLog("%@", message)
    }

    private func applyRunOnStartupState(enabled: Bool) {
        persistRunOnStartup(enabled)
        notifyRunOnStartupChanged(enabled)
    }

    private func persistRunOnStartup(_ enabled: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: UserDefaultsKey.runOnStartup)
        defaults.set(enabled ? 1 : 0, forKey: UserDefaultsKey.runOnStartupLegacy)
    }

    private func notifyRunOnStartupChanged(_ enabled: Bool) {
        NotificationCenter.default.post(
            name: NotificationName.runOnStartupChanged,
            object: nil,
            userInfo: [NotificationUserInfoKey.enabled: enabled]
        )
    }

    private func presentLoginItemApprovalPrompt() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Cần xác nhận trong Cài đặt hệ thống"
        alert.informativeText = """
        macOS yêu cầu bạn bật lại PHTV trong Login Items để cho phép tự khởi động.

        Bạn có muốn mở Cài đặt hệ thống ngay bây giờ không?
        """
        alert.addButton(withTitle: "Mở Cài đặt")
        alert.addButton(withTitle: "Để sau")

        if alert.runModal() == .alertFirstButtonReturn {
            LoginItemService.shared.openSystemLoginItemsSettings()
        }
    }
}
