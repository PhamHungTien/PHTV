//
//  AppDelegate+AppMonitoring.swift
//  PHTV
//
//  Swift port of AppDelegate+AppMonitoring.mm.
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
private let phtvNotificationMenuBarIconSizeChanged = Notification.Name("MenuBarIconSizeChanged")
private let phtvNotificationLanguageChangedFromExcludedApp = Notification.Name("LanguageChangedFromExcludedApp")
private let phtvNotificationTCCDatabaseChanged = Notification.Name("TCCDatabaseChanged")
private let phtvNotificationApplicationDidBecomeActive = NSApplication.didBecomeActiveNotification
private let phtvSpotlightInvalidationDedupMs: UInt64 = 30

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
        if let candidate = entry["bundleIdentifier"] as? String, candidate == bundleIdentifier {
            return true
        }
    }

    return false
}

@MainActor extension AppDelegate {
    @objc func handleExcludedAppsChanged(_ notification: Notification) {
        _ = notification
        if let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           !bundleIdentifier.isEmpty {
            checkExcludedApp(bundleIdentifier)
        }
    }

    @objc func handleSendKeyStepByStepAppsChanged(_ notification: Notification) {
        _ = notification
        if let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           !bundleIdentifier.isEmpty {
            checkSendKeyStepByStepApp(bundleIdentifier)
        }
    }

    @objc func handleUpperCaseExcludedAppsChanged(_ notification: Notification) {
        _ = notification
        if let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           !bundleIdentifier.isEmpty {
            checkUpperCaseExcludedApp(bundleIdentifier)
        }
    }

    @objc func receiveWakeNote(_ note: Notification) {
        _ = note
        _ = PHTVManager.stopEventTap()
        _ = PHTVManager.initEventTap()
        requestEventTapRecovery(reason: "didWake", force: true)
    }

    @objc func receiveSleepNote(_ note: Notification) {
        _ = note
        cancelEventTapRecovery(reason: "willSleep")
        _ = PHTVManager.stopEventTap()
    }

    @objc func handleApplicationDidBecomeActive(_ note: Notification) {
        _ = note
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
            PHTVCacheStateService.updateSpotlightCache(false, pid: 0, bundleId: bundleIdentifier)
            checkExcludedApp(bundleIdentifier)
        }

        if !isInExcludedApp && PHTVManager.isSmartSwitchKeyEnabled() && PHTVManager.isInited() {
            PHTVManager.notifyActiveAppChanged()
        }

        _ = PHTVCacheStateService.invalidateSpotlightCache(dedupWindowMs: phtvSpotlightInvalidationDedupMs)

        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            checkSendKeyStepByStepApp(bundleIdentifier)
            checkUpperCaseExcludedApp(bundleIdentifier)
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
        workspaceCenter.addObserver(self,
                                    selector: #selector(receiveWakeNote(_:)),
                                    name: NSWorkspace.didWakeNotification,
                                    object: nil)
        workspaceCenter.addObserver(self,
                                    selector: #selector(receiveSleepNote(_:)),
                                    name: NSWorkspace.willSleepNotification,
                                    object: nil)
        workspaceCenter.addObserver(self,
                                    selector: #selector(receiveActiveSpaceChanged(_:)),
                                    name: NSWorkspace.activeSpaceDidChangeNotification,
                                    object: nil)
        workspaceCenter.addObserver(self,
                                    selector: #selector(activeAppChanged(_:)),
                                    name: NSWorkspace.didActivateApplicationNotification,
                                    object: nil)

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(onInputMethodChangedFromSwiftUI(_:)),
                           name: phtvNotificationInputMethodChanged,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(onCodeTableChangedFromSwiftUI(_:)),
                           name: phtvNotificationCodeTableChanged,
                           object: nil)
        center.addObserver(self,
                           selector: Selector(("handleHotkeyChanged:")),
                           name: phtvNotificationHotkeyChanged,
                           object: nil)
        center.addObserver(self,
                           selector: Selector(("handleEmojiHotkeySettingsChanged:")),
                           name: phtvNotificationEmojiHotkeySettingsChanged,
                           object: nil)
        center.addObserver(self,
                           selector: Selector(("handleTCCDatabaseChanged:")),
                           name: phtvNotificationTCCDatabaseChanged,
                           object: nil)
        center.addObserver(self,
                           selector: Selector(("handleSettingsChanged:")),
                           name: phtvNotificationSettingsChanged,
                           object: nil)
        center.addObserver(self,
                           selector: Selector(("handleMacrosUpdated:")),
                           name: phtvNotificationMacrosUpdated,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleExcludedAppsChanged(_:)),
                           name: phtvNotificationExcludedAppsChanged,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleSendKeyStepByStepAppsChanged(_:)),
                           name: phtvNotificationSendKeyStepByStepAppsChanged,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleUpperCaseExcludedAppsChanged(_:)),
                           name: phtvNotificationUpperCaseExcludedAppsChanged,
                           object: nil)
        center.addObserver(self,
                           selector: Selector(("handleMenuBarIconSizeChanged:")),
                           name: phtvNotificationMenuBarIconSizeChanged,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleApplicationDidBecomeActive(_:)),
                           name: phtvNotificationApplicationDidBecomeActive,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleLanguageChangedFromSwiftUI(_:)),
                           name: phtvNotificationLanguageChangedFromSwiftUI,
                           object: nil)
        userDefaultsObserver = center.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleUserDefaultsDidChange(nil)
            }
        }

        registerSparkleObservers()
    }
}
