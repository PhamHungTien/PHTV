//
//  AppDelegate+Lifecycle.swift
//  PHTV
//
//  Swift port of AppDelegate lifecycle methods.
//

import AppKit
import Foundation

private let phtvDefaultsKeyShowIconOnDock = "vShowIconOnDock"
private let phtvDefaultsKeyShowUIOnStartup = "ShowUIOnStartup"
private let phtvDefaultsKeyNonFirstTime = "NonFirstTime"
private let phtvDefaultsKeyInitialToolTipDelay = "NSInitialToolTipDelay"

private let phtvNotificationShowSettings = Notification.Name("ShowSettings")
private let phtvNotificationApplicationWillTerminate = Notification.Name("ApplicationWillTerminate")

@MainActor @objc extension AppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        NSLog("🔴🔴🔴 [AppDelegate] applicationDidFinishLaunching STARTED 🔴🔴🔴")

        updateQueue = DispatchQueue(label: "com.phtv.updateQueue")
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

        let defaults = UserDefaults.standard
        let isFirstLaunch = !defaults.bool(forKey: phtvDefaultsKeyNonFirstTime)
        needsRelaunchAfterPermission = isFirstLaunch && !PHTVManager.canCreateEventTap()

        SetAppDelegateInstance(self)

        registerSupportedNotification()

        defaults.set(50, forKey: phtvDefaultsKeyInitialToolTipDelay)

        let runningApps = NSWorkspace.shared.runningApplications
        let currentBundleID = Bundle.main.bundleIdentifier

        for app in runningApps where app.bundleIdentifier == currentBundleID && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            NSLog("Found existing instance (PID: %d), terminating it...", app.processIdentifier)
            app.terminate()
            Thread.sleep(forTimeInterval: 0.5)
            break
        }

        let showDockIcon = defaults.bool(forKey: phtvDefaultsKeyShowIconOnDock)
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)

        setupSwiftUIBridge()

        loadExistingMacros()
        initEnglishWordDictionary()
        loadRuntimeSettingsFromUserDefaults()

        observeAppearanceChanges()

        let binaryIntact = PHTVManager.checkBinaryIntegrity()
        if !binaryIntact {
            NSLog("⚠️⚠️⚠️ [AppDelegate] Binary integrity check FAILED - may cause permission issues")
        }

        PHTVManager.startTCCNotificationListener()
        NSLog("[TCC] Notification listener started at app launch")

        if !PHTVManager.canCreateEventTap() {
            askPermission()
            attemptAutomaticTCCRepairIfNeeded()
            startAccessibilityMonitoring()
            stopHealthCheckMonitoring()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            if !PHTVManager.initEventTap() {
                NotificationCenter.default.post(name: phtvNotificationShowSettings, object: nil)
            } else {
                NSLog("[EventTap] Initialized successfully")
                self.startAccessibilityMonitoring()
                self.startHealthCheckMonitoring()
                self.startInputSourceMonitoring()

                let showUI = UserDefaults.standard.integer(forKey: phtvDefaultsKeyShowUIOnStartup)
                if showUI == 1 {
                    NotificationCenter.default.post(name: phtvNotificationShowSettings, object: nil)
                }
            }

            self.setQuickConvertString()

            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                NSLog("[Sparkle] Checking for updates (delayed start)...")
                SparkleManager.shared().checkForUpdates()
            }
        }

        if isFirstLaunch {
            loadDefaultConfig()
            defaults.set(1, forKey: phtvDefaultsKeyNonFirstTime)
            NSLog("[AppDelegate] First launch: loaded default config and marked NonFirstTime")
        }

        syncRunOnStartupStatus(withFirstLaunch: isFirstLaunch)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        _ = sender
        _ = flag

        onControlPanelSelected()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = notification

        stopInputSourceMonitoring()
        stopAccessibilityMonitoring()
        stopHealthCheckMonitoring()

        PHTVManager.clearAXTestFlag()

        NotificationCenter.default.post(name: phtvNotificationApplicationWillTerminate, object: nil)
    }
}
