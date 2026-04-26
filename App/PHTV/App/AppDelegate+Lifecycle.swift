//
//  AppDelegate+Lifecycle.swift
//  PHTV
//
//  Application lifecycle coordination.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import ApplicationServices
import Foundation

private let phtvDefaultsKeyShowIconOnDock = "vShowIconOnDock"
private let phtvDefaultsKeyShowUIOnStartup = "ShowUIOnStartup"
private let phtvDefaultsKeyNonFirstTime = "NonFirstTime"
private let phtvDefaultsKeyInitialToolTipDelay = "NSInitialToolTipDelay"

private let phtvNotificationShowSettings = NotificationName.showSettings
private let phtvNotificationApplicationWillTerminate = NotificationName.applicationWillTerminate

func phtvIsRunningUnderXCTest() -> Bool {
    let environment = ProcessInfo.processInfo.environment
    return environment["PHTV_RUNNING_XCTEST"] == "1"
        || environment["XCTestConfigurationFilePath"] != nil
        || NSClassFromString("XCTestCase") != nil
        || NSClassFromString("XCTest.XCTestCase") != nil
}

@MainActor @objc extension AppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        NSLog("🔴🔴🔴 [AppDelegate] applicationDidFinishLaunching STARTED 🔴🔴🔴")

        lastInputMethod = -1
        lastCodeTable = -1
        isUpdatingUI = false

        savedLanguageBeforeExclusion = 0
        previousBundleIdentifier = nil
        isInExcludedApp = false

        savedSendKeyStepByStepBeforeApp = false
        isInSendKeyStepByStepApp = false

        isUpdatingLanguage = false
        isUpdatingInputType = false
        isUpdatingCodeTable = false

        SettingsBootstrap.registerDefaults()

        if phtvIsRunningUnderXCTest() {
            setupSwiftUIBridge()
            NSLog("[AppDelegate] XCTest host mode: skipping app launch side effects")
            return
        }

        let defaults = UserDefaults.standard
        let isFirstLaunch = !defaults.bool(forKey: phtvDefaultsKeyNonFirstTime)
        needsRelaunchAfterPermission = !AXIsProcessTrusted()
        if needsRelaunchAfterPermission {
            NSLog("[Accessibility] App launched before Accessibility trust; will relaunch after grant")
        }

        // Set up NSStatusItem + NSMenu (replaces SwiftUI MenuBarExtra for proper submenu hover).
        StatusBarMenuManager.shared.setup()

        registerSupportedNotification()

        defaults.set(50, forKey: phtvDefaultsKeyInitialToolTipDelay)

        let runningApps = NSWorkspace.shared.runningApplications
        let currentBundleID = Bundle.main.bundleIdentifier

        for app in runningApps where app.bundleIdentifier == currentBundleID && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            NSLog("Found existing instance (PID: %d), terminating it...", app.processIdentifier)
            app.terminate()
            break
        }

        let showDockIcon = defaults.bool(forKey: phtvDefaultsKeyShowIconOnDock)
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)

        setupSwiftUIBridge()
        bootstrapSparkleUpdates()

        loadExistingMacros()
        for delay in [0.6, 1.8] {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self, !Task.isCancelled else { return }
                self.refreshMacrosIfSystemTextReplacementsChanged(resetSession: true)
            }
        }
        initEnglishWordDictionary()
        loadRuntimeSettingsFromUserDefaults()
        EmojiHotkeyBridge.initializeEmojiHotkeyManager()
        for delay in [0.0, 0.25, 0.8] {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
            }
        }
        ClipboardHotkeyBridge.initializeClipboardHotkeyManager()
        for delay in [0.0, 0.25, 0.8] {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                ClipboardHotkeyBridge.refreshClipboardHotkeyRegistration()
            }
        }
        runHotkeyHealthCheck(reason: "launch-bootstrap")

        observeAppearanceChanges()

        Task.detached(priority: .utility) {
            let binaryIntact = PHTVBinaryIntegrityService.checkBinaryIntegrity()
            if !binaryIntact {
                NSLog("⚠️⚠️⚠️ [AppDelegate] Binary integrity check FAILED - may cause permission issues")
            }
        }

        PHTVManager.startTCCNotificationListener()
        NSLog("[TCC] Notification listener started at app launch")

        if !PHTVManager.canCreateEventTap() {
            runHotkeyHealthCheck(reason: "launch-no-permission")
            publishTypingPermissionState(eventTapReady: false)
            askPermission()
            attemptAutomaticTCCRepairIfNeeded()
            startAccessibilityMonitoring()
            stopHealthCheckMonitoring()
            return
        }

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else {
                return
            }

            if !PHTVManager.initEventTap() {
                self.publishTypingPermissionState(eventTapReady: false)
                NotificationCenter.default.post(name: phtvNotificationShowSettings, object: nil)
            } else {
                NSLog("[EventTap] Initialized successfully")
                self.startAccessibilityMonitoring()
                self.startHealthCheckMonitoring()
                self.startInputSourceMonitoring()
                EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
                ClipboardHotkeyBridge.refreshClipboardHotkeyRegistration()
                self.publishTypingPermissionState(eventTapReady: true)
                self.syncCurrentFrontmostAppContext(reason: "launch", forceExcludedRecheck: true)

                let showUI = UserDefaults.standard.integer(forKey: phtvDefaultsKeyShowUIOnStartup)
                if showUI == 1 {
                    NotificationCenter.default.post(name: phtvNotificationShowSettings, object: nil)
                }
            }

            self.runHotkeyHealthCheck(reason: "launch-after-eventtap-init")
            self.requestEventTapRecovery(reason: "launch", force: true)
            self.setQuickConvertString()
        }

        if isFirstLaunch {
            loadDefaultConfig()
            defaults.set(1, forKey: phtvDefaultsKeyNonFirstTime)
            NSLog("[AppDelegate] First launch: loaded default config and marked NonFirstTime")
        }

        syncRunOnStartupStatus(withFirstLaunch: isFirstLaunch)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app alive as a menu bar agent when the settings window is closed.
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        _ = sender
        _ = flag

        onControlPanelSelected()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = notification

        AppState.shared.flushPendingSettingsForTermination()
        permissionGuidancePresentationTask?.cancel()
        permissionGuidancePresentationTask = nil
        cancelEventTapRecovery(reason: "applicationWillTerminate")
        cancelManagedNotificationTasks()
        stopInputSourceMonitoring()
        stopAccessibilityMonitoring()
        stopHealthCheckMonitoring()

        PHTVManager.clearAXTestFlag()

        NotificationCenter.default.post(name: phtvNotificationApplicationWillTerminate, object: nil)
    }
}
