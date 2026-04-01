//
//  AppDelegate+AppMonitoring.swift
//  PHTV
//
//  Workspace and app monitoring.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation

private let phtvDefaultsKeyInputMethod = "InputMethod"
private let phtvDefaultsKeyExcludedApps = "ExcludedApps"
private let phtvDefaultsKeySendKeyStepByStepApps = "SendKeyStepByStepApps"
private let phtvDefaultsKeyUpperCaseExcludedApps = "UpperCaseExcludedApps"
private let phtvDefaultsKeySendKeyStepByStep = "SendKeyStepByStep"

private let phtvNotificationInputMethodChanged = Notification.Name("InputMethodChanged")
private let phtvNotificationCodeTableChanged = Notification.Name("CodeTableChanged")
private let phtvNotificationHotkeyChanged = Notification.Name("HotkeyChanged")
private let phtvNotificationEmojiHotkeySettingsChanged = Notification.Name("EmojiHotkeySettingsChanged")
private let phtvNotificationLanguageChangedFromSwiftUI = Notification.Name("LanguageChangedFromSwiftUI")
private let phtvNotificationSettingsChanged = Notification.Name("PHTVSettingsChanged")
private let phtvNotificationMacrosUpdated = Notification.Name("MacrosUpdated")
private let phtvNotificationExcludedAppsChanged = Notification.Name("ExcludedAppsChanged")
private let phtvNotificationSendKeyStepByStepAppsChanged = Notification.Name("SendKeyStepByStepAppsChanged")
private let phtvNotificationUpperCaseExcludedAppsChanged = Notification.Name("UpperCaseExcludedAppsChanged")
private let phtvNotificationLanguageChangedFromExcludedApp = Notification.Name("LanguageChangedFromExcludedApp")
private let phtvNotificationTCCDatabaseChanged = Notification.Name("TCCDatabaseChanged")
private let phtvNotificationApplicationDidBecomeActive = NSApplication.didBecomeActiveNotification
private let phtvSpotlightInvalidationDedupMs: UInt64 = 30
private let phtvSpotlightBundleIdentifier = "com.apple.Spotlight"
private let phtvEmojiHotkeyWakeRefreshDelays: [TimeInterval] = [0.0, 0.3, 1.0]
private let phtvClipboardHotkeyWakeRefreshDelays: [TimeInterval] = [0.0, 0.3, 1.0]

private func phtvDecodeAppList(_ data: Data?) -> [[String: Any]]? {
    guard let data, !data.isEmpty else {
        return nil
    }

    guard let decoded = try? JSONSerialization.jsonObject(with: data, options: []),
          let appList = decoded as? [[String: Any]] else {
        return nil
    }

    return appList
}

private func phtvListContainsBundleIdentifier(_ appList: [[String: Any]]?, bundleIdentifier: String) -> Bool {
    guard !bundleIdentifier.isEmpty, let appList, !appList.isEmpty else {
        return false
    }

    for entry in appList {
        if let candidate = entry["bundleIdentifier"] as? String,
           PHTVAppDetectionService.bundleId(bundleIdentifier, matchesAppListBundleId: candidate) {
            return true
        }
    }

    return false
}

@MainActor extension AppDelegate {
    private func bundleIdentifierForAppListChecks(frontmostBundleIdentifier: String) -> String {
        guard !frontmostBundleIdentifier.isEmpty else {
            return frontmostBundleIdentifier
        }

        _ = PHTVCacheStateService.invalidateSpotlightCache(dedupWindowMs: phtvSpotlightInvalidationDedupMs)
        guard PHTVSpotlightDetectionService.isSpotlightActive() else {
            return frontmostBundleIdentifier
        }

        if let focusedBundleIdentifier = PHTVCacheStateService.cachedFocusedBundleId(),
           !focusedBundleIdentifier.isEmpty {
            return focusedBundleIdentifier
        }

        return phtvSpotlightBundleIdentifier
    }

    private func refreshAppListContexts(forFrontmostBundleIdentifier frontmostBundleIdentifier: String,
                                        forceExcludedRecheck: Bool = false) {
        let effectiveBundleIdentifier = bundleIdentifierForAppListChecks(
            frontmostBundleIdentifier: frontmostBundleIdentifier
        )

        if forceExcludedRecheck {
            previousBundleIdentifier = nil
        }

        if effectiveBundleIdentifier != frontmostBundleIdentifier {
            NSLog(
                "[AppContext] Resolved effective app-list bundle '%@' from frontmost '%@'",
                effectiveBundleIdentifier,
                frontmostBundleIdentifier
            )
        }

        checkExcludedApp(effectiveBundleIdentifier)
        checkSendKeyStepByStepApp(effectiveBundleIdentifier)
        checkUpperCaseExcludedApp(effectiveBundleIdentifier)
    }

    private func applyFrontmostAppContext(_ bundleIdentifier: String) {
        PHTVAppContextService.updateFrontmostBundleCache(bundleIdentifier)
        refreshAppListContexts(forFrontmostBundleIdentifier: bundleIdentifier)

        if !isInExcludedApp && PHTVManager.isSmartSwitchKeyEnabled() && PHTVManager.isInited() {
            PHTVManager.notifyActiveAppChanged()
        }
    }

    func syncCurrentFrontmostAppContext(reason: String, forceExcludedRecheck: Bool = false) {
        guard let bundleIdentifier = PHTVAppContextService.currentFrontmostBundleId(),
              !bundleIdentifier.isEmpty else {
            PHTVAppContextService.invalidateFrontmostBundleCache()
            return
        }

        if forceExcludedRecheck {
            previousBundleIdentifier = nil
        }

        applyFrontmostAppContext(bundleIdentifier)
        NSLog("[AppContext] Synced frontmost app context (%@): %@", reason, bundleIdentifier)
    }

    private func refreshEmojiHotkeyRegistration(reason: String, settledRetries: Bool) {
        let delays = settledRetries ? phtvEmojiHotkeyWakeRefreshDelays : [0.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
            }
        }
#if DEBUG
        NSLog("[EmojiHotkey] Scheduled refresh (%@), retries=%@", reason, settledRetries ? "YES" : "NO")
#endif
    }

    private func refreshClipboardHotkeyRegistration(reason: String, settledRetries: Bool) {
        let delays = settledRetries ? phtvClipboardHotkeyWakeRefreshDelays : [0.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                ClipboardHotkeyBridge.refreshClipboardHotkeyRegistration()
            }
        }
#if DEBUG
        NSLog("[ClipboardHotkey] Scheduled refresh (%@), retries=%@", reason, settledRetries ? "YES" : "NO")
#endif
    }

    @objc func handleExcludedAppsChanged(_ notification: Notification) {
        _ = notification
        if let bundleIdentifier = PHTVAppContextService.currentFrontmostBundleId(),
           !bundleIdentifier.isEmpty {
            refreshAppListContexts(
                forFrontmostBundleIdentifier: bundleIdentifier,
                forceExcludedRecheck: true
            )
        }
    }

    @objc func handleSendKeyStepByStepAppsChanged(_ notification: Notification) {
        _ = notification
        if let bundleIdentifier = PHTVAppContextService.currentFrontmostBundleId(),
           !bundleIdentifier.isEmpty {
            refreshAppListContexts(forFrontmostBundleIdentifier: bundleIdentifier)
        }
    }

    @objc func handleUpperCaseExcludedAppsChanged(_ notification: Notification) {
        _ = notification
        if let bundleIdentifier = PHTVAppContextService.currentFrontmostBundleId(),
           !bundleIdentifier.isEmpty {
            refreshAppListContexts(forFrontmostBundleIdentifier: bundleIdentifier)
        }
    }

    @objc func receiveWakeNote(_ note: Notification) {
        _ = note
        _ = PHTVManager.stopEventTap()
        publishTypingPermissionState(eventTapReady: false)

        let initSucceeded = PHTVManager.initEventTap()
        let eventTapReady = initSucceeded && PHTVManager.isEventTapEnabled()
        publishTypingPermissionState(eventTapReady: eventTapReady)
        startInputSourceMonitoring()
        if eventTapReady {
            startHealthCheckMonitoring()
        } else {
            stopHealthCheckMonitoring()
        }
        syncCurrentFrontmostAppContext(reason: "didWake", forceExcludedRecheck: true)

        refreshEmojiHotkeyRegistration(reason: "didWake", settledRetries: true)
        refreshClipboardHotkeyRegistration(reason: "didWake", settledRetries: true)
        requestEventTapRecovery(reason: "didWake", force: true)
    }

    @objc func receiveSleepNote(_ note: Notification) {
        _ = note
        cancelEventTapRecovery(reason: "willSleep")
        stopHealthCheckMonitoring()
        _ = PHTVManager.stopEventTap()
        publishTypingPermissionState(eventTapReady: false)
    }

    @objc func handleApplicationDidBecomeActive(_ note: Notification) {
        _ = note
        refreshEmojiHotkeyRegistration(reason: "didBecomeActive", settledRetries: false)
        refreshClipboardHotkeyRegistration(reason: "didBecomeActive", settledRetries: false)
        requestEventTapRecovery(reason: "didBecomeActive")
    }

    @objc func receiveActiveSpaceChanged(_ note: Notification) {
        _ = note
        PHTVManager.requestNewSession()
    }

    @objc func activeAppChanged(_ note: Notification) {
        let activeApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        let bundleIdentifier = activeApp?.bundleIdentifier

        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            applyFrontmostAppContext(bundleIdentifier)
        } else {
            PHTVAppContextService.invalidateFrontmostBundleCache()
        }
    }

    @objc func checkExcludedApp(_ bundleIdentifier: String) {
        if bundleIdentifier.isEmpty || bundleIdentifier == previousBundleIdentifier {
            return
        }

        let excludedApps = phtvDecodeAppList(UserDefaults.standard.data(forKey: phtvDefaultsKeyExcludedApps))
        let isExcluded = phtvListContainsBundleIdentifier(excludedApps, bundleIdentifier: bundleIdentifier)

        let currentLanguage = Int(PHTVManager.currentLanguage())

        if isExcluded && !isInExcludedApp {
            savedLanguageBeforeExclusion = currentLanguage
            isInExcludedApp = true

            if currentLanguage == 1 {
                PHTVManager.setCurrentLanguage(0)
                UserDefaults.standard.set(0, forKey: phtvDefaultsKeyInputMethod)
                PHTVManager.requestNewSession()
                fillData()

                NSLog("[ExcludedApp] Entered excluded app '%@' - switched to English (saved state: Vietnamese)", bundleIdentifier)

                NotificationCenter.default.post(name: phtvNotificationLanguageChangedFromExcludedApp,
                                                object: NSNumber(value: 0))
            } else {
                NSLog("[ExcludedApp] Entered excluded app '%@' - already in English (saved state: English)", bundleIdentifier)
            }
        } else if !isExcluded && isInExcludedApp {
            isInExcludedApp = false

            if savedLanguageBeforeExclusion == 1 && currentLanguage == 0 {
                PHTVManager.setCurrentLanguage(1)
                UserDefaults.standard.set(1, forKey: phtvDefaultsKeyInputMethod)
                PHTVManager.requestNewSession()
                fillData()

                NSLog("[ExcludedApp] Left excluded app, switched to '%@' - restored Vietnamese mode", bundleIdentifier)

                NotificationCenter.default.post(name: phtvNotificationLanguageChangedFromExcludedApp,
                                                object: NSNumber(value: 1))
            } else {
                NSLog("[ExcludedApp] Left excluded app, switched to '%@' - staying in English", bundleIdentifier)
            }
        } else if isExcluded && isInExcludedApp {
            NSLog("[ExcludedApp] Moved from excluded app to another excluded app '%@' - staying in English", bundleIdentifier)
        }

        previousBundleIdentifier = bundleIdentifier
    }

    @objc func checkSendKeyStepByStepApp(_ bundleIdentifier: String) {
        if bundleIdentifier.isEmpty {
            return
        }

        let appList = phtvDecodeAppList(UserDefaults.standard.data(forKey: phtvDefaultsKeySendKeyStepByStepApps))
        let isInList = phtvListContainsBundleIdentifier(appList, bundleIdentifier: bundleIdentifier)
        let sendKeyStepByStepEnabled = PHTVManager.isSendKeyStepByStepEnabled()

        if isInList && !isInSendKeyStepByStepApp {
            savedSendKeyStepByStepBeforeApp = sendKeyStepByStepEnabled
            isInSendKeyStepByStepApp = true

            if !sendKeyStepByStepEnabled {
                PHTVManager.setSendKeyStepByStepEnabled(true)
                UserDefaults.standard.set(true, forKey: phtvDefaultsKeySendKeyStepByStep)
                NSLog("[SendKeyStepByStepApp] Entered app '%@' - enabled send key step by step", bundleIdentifier)
            } else {
                NSLog("[SendKeyStepByStepApp] Entered app '%@' - already enabled", bundleIdentifier)
            }
        } else if !isInList && isInSendKeyStepByStepApp {
            isInSendKeyStepByStepApp = false

            if !savedSendKeyStepByStepBeforeApp && sendKeyStepByStepEnabled {
                PHTVManager.setSendKeyStepByStepEnabled(false)
                UserDefaults.standard.set(false, forKey: phtvDefaultsKeySendKeyStepByStep)
                NSLog("[SendKeyStepByStepApp] Left app '%@' - disabled send key step by step", bundleIdentifier)
            } else {
                NSLog("[SendKeyStepByStepApp] Left app '%@' - keeping send key step by step state", bundleIdentifier)
            }
        } else if isInList && isInSendKeyStepByStepApp {
            NSLog("[SendKeyStepByStepApp] Moved to another app in list '%@' - keeping enabled", bundleIdentifier)
        }
    }

    @objc func checkUpperCaseExcludedApp(_ bundleIdentifier: String) {
        if bundleIdentifier.isEmpty {
            return
        }

        let appList = phtvDecodeAppList(UserDefaults.standard.data(forKey: phtvDefaultsKeyUpperCaseExcludedApps))
        let isExcluded = phtvListContainsBundleIdentifier(appList, bundleIdentifier: bundleIdentifier)
        PHTVManager.setUpperCaseExcludedForCurrentApp(isExcluded)

        if isExcluded {
            NSLog("[UpperCaseExcludedApp] App '%@' is excluded from uppercase first char", bundleIdentifier)
        }
    }

    @objc func registerSupportedNotification() {
#if DEBUG
        NSLog("[AppMonitoring] registerSupportedNotification registering observers")
#endif

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        monitoringNotificationTasks.forEach { $0.cancel() }
        monitoringNotificationTasks = [
            makeNotificationTask(center: workspaceCenter, name: NSWorkspace.didWakeNotification) { appDelegate, notification in
                appDelegate.receiveWakeNote(notification)
            },
            makeNotificationTask(center: workspaceCenter, name: NSWorkspace.willSleepNotification) { appDelegate, notification in
                appDelegate.receiveSleepNote(notification)
            },
            makeNotificationTask(center: workspaceCenter, name: NSWorkspace.activeSpaceDidChangeNotification) { appDelegate, notification in
                appDelegate.receiveActiveSpaceChanged(notification)
            },
            makeNotificationTask(center: workspaceCenter, name: NSWorkspace.didActivateApplicationNotification) { appDelegate, notification in
                appDelegate.activeAppChanged(notification)
            }
        ]

        let center = NotificationCenter.default
        monitoringNotificationTasks += [
            makeNotificationTask(center: center, name: phtvNotificationInputMethodChanged) { appDelegate, notification in
                appDelegate.onInputMethodChangedFromSwiftUI(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationCodeTableChanged) { appDelegate, notification in
                appDelegate.onCodeTableChangedFromSwiftUI(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationHotkeyChanged) { appDelegate, notification in
                appDelegate.handleHotkeyChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationEmojiHotkeySettingsChanged) { appDelegate, notification in
                appDelegate.handleEmojiHotkeySettingsChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationTCCDatabaseChanged) { appDelegate, notification in
                appDelegate.handleTCCDatabaseChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationSettingsChanged) { appDelegate, notification in
                appDelegate.handleSettingsChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationMacrosUpdated) { appDelegate, notification in
                appDelegate.handleMacrosUpdated(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationExcludedAppsChanged) { appDelegate, notification in
                appDelegate.handleExcludedAppsChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationSendKeyStepByStepAppsChanged) { appDelegate, notification in
                appDelegate.handleSendKeyStepByStepAppsChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationUpperCaseExcludedAppsChanged) { appDelegate, notification in
                appDelegate.handleUpperCaseExcludedAppsChanged(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationApplicationDidBecomeActive) { appDelegate, notification in
                appDelegate.handleApplicationDidBecomeActive(notification)
            },
            makeNotificationTask(center: center, name: phtvNotificationLanguageChangedFromSwiftUI) { appDelegate, notification in
                appDelegate.handleLanguageChangedFromSwiftUI(notification)
            },
            makeNotificationTask(center: center, name: UserDefaults.didChangeNotification) { appDelegate, notification in
                appDelegate.handleUserDefaultsDidChange(notification)
            }
        ]

        registerSparkleObservers()
    }
}
