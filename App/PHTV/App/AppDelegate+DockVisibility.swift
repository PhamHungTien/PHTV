//
//  AppDelegate+DockVisibility.swift
//  PHTV
//
//  Swift port of AppDelegate+DockVisibility.mm.
//

import AppKit
import Foundation

private let phtvDefaultsKeyShowIconOnDock = "vShowIconOnDock"
private let phtvNotificationUserInfoVisibleKey = "visible"
private let phtvNotificationUserInfoForceFrontKey = "forceFront"
private let phtvSpotlightInvalidationDedupMs: UInt64 = 30

private func phtvLiveDebugEnabledSwift() -> Bool {
    if let env = ProcessInfo.processInfo.environment["PHTV_LIVE_DEBUG"], !env.isEmpty {
        return env != "0"
    }

    if let stored = UserDefaults.standard.object(forKey: "PHTV_LIVE_DEBUG") as? NSNumber {
        return stored.intValue != 0
    }

    return false
}

private func phtvDockLog(_ message: String) {
    guard phtvLiveDebugEnabledSwift() else {
        return
    }
    NSLog("[PHTV Live] %@", message)
}

@MainActor
private func phtvSettingsIdentifier(_ window: NSWindow) -> String? {
    return window.identifier?.rawValue
}

@MainActor @objc extension AppDelegate {
    func currentSettingsWindow() -> NSWindow? {
        for window in NSApp.windows {
            if let identifier = phtvSettingsIdentifier(window), identifier.hasPrefix("settings") {
                return window
            }
        }
        return nil
    }

    func isSettingsWindowVisible() -> Bool {
        guard let window = currentSettingsWindow() else {
            return false
        }
        return window.isVisible
    }

    func handleShowDockIconNotification(_ notification: Notification?) {
        let userInfo = notification?.userInfo ?? [:]
        let desiredDockVisible = (userInfo[phtvNotificationUserInfoVisibleKey] as? NSNumber)?.boolValue ?? false
        let shouldForceFront = (userInfo[phtvNotificationUserInfoForceFrontKey] as? NSNumber)?.boolValue ?? false

        let now = CFAbsoluteTimeGetCurrent()
        let sameAsLastRequest =
            hasLastDockVisibilityRequest &&
            lastDockVisibilityRequest == desiredDockVisible &&
            lastDockForceFrontRequest == shouldForceFront

        if sameAsLastRequest && !shouldForceFront &&
            (now - lastDockVisibilityRequestTime) < 0.20 {
            return
        }

        hasLastDockVisibilityRequest = true
        lastDockVisibilityRequest = desiredDockVisible
        lastDockForceFrontRequest = shouldForceFront
        lastDockVisibilityRequestTime = now

        phtvDockLog("handleShowDockIconNotification: visible=\(desiredDockVisible ? 1 : 0) forceFront=\(shouldForceFront ? 1 : 0)")

        let wasSettingsOpen = settingsWindowOpen
        let settingsWindow = currentSettingsWindow()
        let settingsVisible = settingsWindow?.isVisible == true
        settingsWindowOpen = settingsVisible
        let shouldResetSession = wasSettingsOpen && !settingsVisible

        if settingsVisible {
            NSApp.setActivationPolicy(.regular)

            if shouldForceFront, let settingsWindow {
                let alreadyFront = NSApp.isActive && (settingsWindow.isKeyWindow || settingsWindow.isMainWindow)
                if !alreadyFront {
                    NSApp.activate(ignoringOtherApps: true)
                    settingsWindow.makeKeyAndOrderFront(nil)
                    phtvDockLog("Brought settings window to front: \(phtvSettingsIdentifier(settingsWindow) ?? "unknown")")
                }
            } else {
                phtvDockLog("Settings window visible; skip force front to avoid reopen loop")
            }
        } else {
            let policy: NSApplication.ActivationPolicy = desiredDockVisible ? .regular : .accessory
            NSApp.setActivationPolicy(policy)
            phtvDockLog("Dock icon restored to desired visibility: \(desiredDockVisible ? 1 : 0)")
        }

        if shouldResetSession {
            PHTVManager.requestNewSession()
            _ = PHTVCacheStateService.invalidateSpotlightCache(dedupWindowMs: phtvSpotlightInvalidationDedupMs)
        }
    }

    func setDockIconVisible(_ visible: Bool) {
        phtvDockLog("setDockIconVisible called with: \(visible ? 1 : 0)")
        settingsWindowOpen = visible

        if visible {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            let userPrefersDock = UserDefaults.standard.bool(forKey: phtvDefaultsKeyShowIconOnDock)
            let policy: NSApplication.ActivationPolicy = userPrefersDock ? .regular : .accessory
            NSApp.setActivationPolicy(policy)
        }
    }

    func showIcon(_ onDock: Bool) {
        phtvDockLog("showIcon called with onDock: \(onDock ? 1 : 0)")

        UserDefaults.standard.set(onDock, forKey: phtvDefaultsKeyShowIconOnDock)
        PHTVManager.setDockIconRuntimeVisible(onDock)

        if isSettingsWindowVisible() {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            for window in NSApp.windows {
                if let identifier = phtvSettingsIdentifier(window), identifier.hasPrefix("settings") {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    break
                }
            }
            return
        }

        let policy: NSApplication.ActivationPolicy = onDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)

        if onDock {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
