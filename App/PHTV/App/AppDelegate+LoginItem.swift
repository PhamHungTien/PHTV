//
//  AppDelegate+LoginItem.swift
//  PHTV
//
//  Login item registration and status sync.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation
import ServiceManagement

@MainActor @objc extension AppDelegate {
    private func isRunOnStartupEffectivelyEnabled(_ status: SMAppService.Status) -> Bool {
        switch status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    @objc(syncRunOnStartupStatusWithFirstLaunch:)
    func syncRunOnStartupStatus(withFirstLaunch isFirstLaunch: Bool) {
        _ = isFirstLaunch
        refreshRunOnStartupStatus(context: "startup-sync")
    }

    @objc(setRunOnStartup:)
    func setRunOnStartup(_ shouldEnable: Bool) {
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            if shouldEnable, SMAppService.mainApp.status == .requiresApproval {
                NSLog("[LoginItem] ℹ️ Enable requested but approval is pending; opening System Settings > Login Items")
                SMAppService.openSystemSettingsLoginItems()
            }

            // Keep UI state aligned with user intent first; verification comes shortly after.
            persistRunOnStartupState(enabled: shouldEnable)
            postRunOnStartupChanged(enabled: shouldEnable)

            let verificationDelays: [TimeInterval] = shouldEnable ? [0.5, 1.5] : [0.5]
            for delay in verificationDelays {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    self?.refreshRunOnStartupStatus(
                        context: shouldEnable
                            ? "request-enable-verify"
                            : "request-disable-verify"
                    )
                }
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
            refreshRunOnStartupStatus(context: shouldEnable ? "request-enable-failed" : "request-disable-failed")
        }
    }

    @objc(toggleStartupItem:)
    func toggleStartupItem(_ sender: NSMenuItem) {
        _ = sender

        let currentEnabled = isRunOnStartupEffectivelyEnabled(SMAppService.mainApp.status)

        setRunOnStartup(!currentEnabled)
        fillData()
    }

    private func refreshRunOnStartupStatus(context: String) {
        let status = SMAppService.mainApp.status
        let enabled = isRunOnStartupEffectivelyEnabled(status)

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
