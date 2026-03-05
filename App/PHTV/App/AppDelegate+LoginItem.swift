//
//  AppDelegate+LoginItem.swift
//  PHTV
//
//  Swift port of AppDelegate+LoginItem.mm.
//

import AppKit
import Foundation
import ServiceManagement

@MainActor @objc extension AppDelegate {
    @objc(syncRunOnStartupStatusWithFirstLaunch:)
    func syncRunOnStartupStatus(withFirstLaunch isFirstLaunch: Bool) {
        _ = isFirstLaunch
        refreshRunOnStartupStatus(context: "startup-sync")
    }

    @objc(setRunOnStartup:)
    func setRunOnStartup(_ shouldEnable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if shouldEnable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                let nsError = error as NSError
                NSLog(
                    "[LoginItem] ❌ Failed to %@ login item: %@ (domain=%@ code=%ld)",
                    shouldEnable ? "register" : "unregister",
                    nsError.localizedDescription,
                    nsError.domain,
                    nsError.code
                )
            }

            refreshRunOnStartupStatus(context: shouldEnable ? "request-enable" : "request-disable")
            return
        }

        // Legacy fallback.
        persistRunOnStartupState(enabled: shouldEnable)
        postRunOnStartupChanged(enabled: shouldEnable)
    }

    @objc(toggleStartupItem:)
    func toggleStartupItem(_ sender: NSMenuItem) {
        _ = sender

        let currentEnabled: Bool
        if #available(macOS 13.0, *) {
            currentEnabled = (SMAppService.mainApp.status == .enabled)
        } else {
            currentEnabled = UserDefaults.standard.bool(
                forKey: UserDefaultsKey.runOnStartup,
                default: Defaults.runOnStartup
            )
        }

        setRunOnStartup(!currentEnabled)
        fillData()
    }

    private func refreshRunOnStartupStatus(context: String) {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            let enabled = (status == .enabled)

            persistRunOnStartupState(enabled: enabled)
            postRunOnStartupChanged(enabled: enabled)

            switch status {
            case .enabled:
                NSLog("[LoginItem] ✅ %@: enabled", context)
            case .notRegistered:
                NSLog("[LoginItem] ℹ️ %@: not registered", context)
            case .requiresApproval:
                NSLog("[LoginItem] ⚠️ %@: requires user approval in System Settings > Login Items", context)
            case .notFound:
                NSLog("[LoginItem] ⚠️ %@: login item not found; try toggling off/on", context)
            @unknown default:
                NSLog("[LoginItem] ⚠️ %@: unknown SMAppService status=%ld", context, status.rawValue)
            }

            return
        }

        let enabled = UserDefaults.standard.bool(
            forKey: UserDefaultsKey.runOnStartup,
            default: Defaults.runOnStartup
        )
        persistRunOnStartupState(enabled: enabled)
        postRunOnStartupChanged(enabled: enabled)
        NSLog("[LoginItem] ℹ️ %@: legacy mode %@", context, enabled ? "enabled" : "disabled")
    }

    private func persistRunOnStartupState(enabled: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: UserDefaultsKey.runOnStartup)
        defaults.set(enabled ? 1 : 0, forKey: UserDefaultsKey.runOnStartupLegacy)
    }

    private func postRunOnStartupChanged(enabled: Bool) {
        NotificationCenter.default.post(
            name: NotificationName.runOnStartupChanged,
            object: nil,
            userInfo: [NotificationUserInfoKey.enabled: enabled]
        )
    }
}
