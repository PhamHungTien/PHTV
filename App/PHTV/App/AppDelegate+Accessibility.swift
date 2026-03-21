//
//  AppDelegate+Accessibility.swift
//  PHTV
//
//  Swift port of AppDelegate+Accessibility.mm.
//

import AppKit
import Foundation

private let phtvDefaultsKeyShowUIOnStartup = "ShowUIOnStartup"
private let phtvDefaultsKeyLastRunVersion = "LastRunVersion"

@MainActor private var phtvIsShowingRelaunchAlert = false

@MainActor @objc extension AppDelegate {
    @nonobjc
    func publishTypingPermissionState(eventTapReady: Bool? = nil) {
        let isReady = eventTapReady ?? (PHTVManager.isInited() && PHTVManager.isEventTapEnabled())
        NotificationCenter.default.post(
            name: NotificationName.accessibilityStatusChanged,
            object: NSNumber(value: isReady)
        )
        NSLog("[Accessibility] Published typing readiness: %@", isReady ? "READY" : "WAITING")
    }

    func startAccessibilityMonitoring() {
        startAccessibilityMonitoring(withInterval: currentMonitoringInterval(), resetState: true)
    }

    func startAccessibilityMonitoring(withInterval interval: TimeInterval) {
        startAccessibilityMonitoring(withInterval: interval, resetState: true)
    }

    func startAccessibilityMonitoring(withInterval interval: TimeInterval, resetState: Bool) {
        stopAccessibilityMonitoring()

        accessibilityMonitor = Timer.scheduledTimer(timeInterval: interval,
                                                    target: self,
                                                    selector: #selector(checkAccessibilityStatus),
                                                    userInfo: nil,
                                                    repeats: true)
        accessibilityMonitor?.tolerance = interval * 0.2

        if resetState {
            wasAccessibilityEnabled = PHTVManager.canCreateEventTap()
        }

        NSLog("[Accessibility] Started monitoring via test event tap (interval: %.1fs, resetState: %@)",
              interval,
              resetState ? "YES" : "NO")
    }

    func currentMonitoringInterval() -> TimeInterval {
        return wasAccessibilityEnabled ? 20.0 : 1.0
    }

    func stopAccessibilityMonitoring() {
        accessibilityMonitor?.invalidate()
        accessibilityMonitor = nil
#if DEBUG
        NSLog("[Accessibility] Stopped monitoring")
#endif
    }

    func startHealthCheckMonitoring() {
        stopHealthCheckMonitoring()

        healthCheckTimer = Timer.scheduledTimer(timeInterval: 10.0,
                                                target: self,
                                                selector: #selector(runHealthCheck),
                                                userInfo: nil,
                                                repeats: true)
        healthCheckTimer?.tolerance = 1.0
    }

    func stopHealthCheckMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    func runHealthCheck() {
        if !PHTVManager.canCreateEventTap() {
            return
        }
        PHTVManager.ensureEventTapAlive()
    }

    func checkAccessibilityStatus() {
        let isEnabled = PHTVManager.canCreateEventTap()
        let statusChanged = (wasAccessibilityEnabled != isEnabled)

        if statusChanged {
            NSLog("[Accessibility] Status CHANGED: was=%@, now=%@",
                  wasAccessibilityEnabled ? "YES" : "NO",
                  isEnabled ? "YES" : "NO")

            let newInterval: TimeInterval = isEnabled ? 20.0 : 1.0
            NSLog("[Accessibility] Adjusting monitoring interval to %.1fs", newInterval)
            startAccessibilityMonitoring(withInterval: newInterval, resetState: false)
        }

        if !wasAccessibilityEnabled && isEnabled {
            NSLog("[Accessibility] ✅ Permission GRANTED (via test tap) - Initializing...")
            accessibilityStableCount = 0
            publishTypingPermissionState(eventTapReady: false)
            performAccessibilityGrantedRestart()
        } else if wasAccessibilityEnabled && !isEnabled {
            NSLog("[Accessibility] 🛑 CRITICAL - Permission REVOKED (test tap failed)!")
            accessibilityStableCount = 0
            handleAccessibilityRevoked()
        } else if isEnabled {
            accessibilityStableCount += 1
        }

        wasAccessibilityEnabled = isEnabled
    }

    func performAccessibilityGrantedRestart() {
        NSLog("[Accessibility] Permission granted - Initializing event tap...")

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        UserDefaults.standard.set(currentVersion, forKey: phtvDefaultsKeyLastRunVersion)

        stopAccessibilityMonitoring()
        PHTVManager.invalidatePermissionCache()

        DispatchQueue.main.async {
            var initSuccess = false

            for attempt in 1...3 {
                NSLog("[EventTap] Init attempt %d/3", attempt)

                if PHTVManager.initEventTap() {
                    NSLog("[EventTap] Initialized successfully on attempt %d - App ready!", attempt)
                    initSuccess = true
                    break
                }

                if attempt < 3 {
                    usleep(useconds_t(100_000 * attempt))
                    PHTVManager.invalidatePermissionCache()
                }
            }

            if !initSuccess {
                NSLog("[EventTap] Failed to initialize after 3 attempts")
                self.publishTypingPermissionState(eventTapReady: false)

                let alert = NSAlert()
                alert.messageText = "🔄 Cần khởi động lại ứng dụng"
                alert.informativeText = "PHTV đã nhận quyền nhưng cần khởi động lại để quyền có hiệu lực.\n\nBạn có muốn khởi động lại ngay không?"
                alert.addButton(withTitle: "Khởi động lại ngay")
                alert.addButton(withTitle: "Để sau")
                alert.alertStyle = .informational

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.relaunchAppAfterPermissionGrant()
                } else {
                    self.startAccessibilityMonitoring(withInterval: 1.0, resetState: false)
                    self.requestEventTapRecovery(reason: "accessibilityGrantedInitFailed", force: true)
                    self.onControlPanelSelected()
                }
            } else {
                self.startAccessibilityMonitoring()
                self.startHealthCheckMonitoring()
                self.startInputSourceMonitoring()
                self.requestEventTapRecovery(reason: "accessibilityGranted", force: true)
                EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
                self.runHotkeyHealthCheck(reason: "accessibility-granted")
                PHTVManager.startTCCNotificationListener()
                self.fillData(withAnimation: true)
                self.publishTypingPermissionState(eventTapReady: true)
                self.syncCurrentFrontmostAppContext(reason: "accessibilityGranted", forceExcludedRecheck: true)

                let showUI = UserDefaults.standard.integer(forKey: phtvDefaultsKeyShowUIOnStartup)
                if showUI == 1 {
                    self.onControlPanelSelected()
                }

                if self.needsRelaunchAfterPermission {
                    self.needsRelaunchAfterPermission = false
                    NSLog("[Accessibility] Initialized successfully - skipping forced relaunch")
                }
            }

            self.setQuickConvertString()
        }
    }

    func relaunchAppAfterPermissionGrant() {
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.isEmpty {
            NSLog("[Accessibility] Relaunch skipped: bundle path missing")
            return
        }

        let bundleURL = URL(fileURLWithPath: bundlePath)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, error in
                if let error {
                    NSLog("[Accessibility] Relaunch failed: %@", error.localizedDescription)
                    return
                }
                NSLog("[Accessibility] Relaunching app to finalize permission")
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func handleAccessibilityRevoked() {
        if PHTVManager.isInited() {
            NSLog("🛑 CRITICAL: Accessibility revoked! Stopping event tap immediately...")
            PHTVManager.stopEventTap()
        }
        publishTypingPermissionState(eventTapReady: false)

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "⚠️  Quyền trợ năng đã bị tắt!"
            alert.informativeText = "PHTV cần quyền trợ năng để hoạt động.\n\nỨng dụng sẽ tự động hoạt động lại khi bạn cấp quyền."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Mở cài đặt")
            alert.addButton(withTitle: "Đóng")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                PHTVAccessibilityService.openAccessibilityPreferences()
                PHTVManager.invalidatePermissionCache()
                NSLog("[Accessibility] User opening System Settings to re-grant")
            }

        }

        attemptAutomaticTCCRepairIfNeeded()
    }

    func attemptAutomaticTCCRepairIfNeeded() {
        if isAttemptingTCCRepair || didAttemptTCCRepairOnce {
            return
        }
        isAttemptingTCCRepair = true

        Task.detached(priority: .userInitiated) {
            let isCorrupt = PHTVManager.isTCCEntryCorrupt()
            if !isCorrupt {
                await MainActor.run {
                    if let app = AppDelegate.current() {
                        app.isAttemptingTCCRepair = false
                    }
                }
                return
            }

            NSLog("[Accessibility] ⚠️ TCC entry missing/corrupt - attempting automatic repair")

            var fixed = false
            var repairError: Error?
            var objcError: NSError?
            if PHTVManager.autoFixTCCEntry(withError: &objcError) {
                fixed = true
            } else {
                repairError = objcError ?? NSError(
                    domain: "PHTV.TCCRepair",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Automatic TCC repair failed"]
                )
            }
            if fixed {
                NSLog("[Accessibility] ✅ TCC auto-repair succeeded, restarting tccd...")
                PHTVManager.restartTCCDaemon()
                PHTVManager.invalidatePermissionCache()
            } else {
                NSLog("[Accessibility] ❌ TCC auto-repair failed: %@",
                      repairError?.localizedDescription ?? "unknown error")
            }

            await MainActor.run {
                guard let app = AppDelegate.current() else {
                    return
                }
                if fixed {
                    app.startAccessibilityMonitoring(withInterval: 0.3, resetState: true)
                }
                app.didAttemptTCCRepairOnce = true
                app.isAttemptingTCCRepair = false
            }
        }
    }

    func handleAccessibilityNeedsRelaunch() {
        if phtvIsShowingRelaunchAlert {
            return
        }

        phtvIsShowingRelaunchAlert = true
        NSLog("[Accessibility] 🔄 Handling relaunch request - permission granted but not effective yet")

        DispatchQueue.main.async {
            if !PHTVManager.isInited() {
                NSLog("[Accessibility] Attempting event tap initialization before relaunch prompt...")
                if PHTVManager.initEventTap() {
                    NSLog("[Accessibility] ✅ Event tap initialized successfully! No relaunch needed.")
                    phtvIsShowingRelaunchAlert = false

                    self.startAccessibilityMonitoring()
                    self.startHealthCheckMonitoring()
                    self.startInputSourceMonitoring()
                    self.requestEventTapRecovery(reason: "accessibilityNeedsRelaunch", force: true)
                    self.fillData(withAnimation: true)
                    self.publishTypingPermissionState(eventTapReady: true)
                    self.syncCurrentFrontmostAppContext(reason: "accessibilityNeedsRelaunch", forceExcludedRecheck: true)
                    return
                }
            }

            let alert = NSAlert()
            alert.messageText = "🔄 Cần khởi động lại ứng dụng"
            alert.informativeText = "PHTV đã nhận được quyền trợ năng từ hệ thống, nhưng cần khởi động lại để quyền có hiệu lực.\n\nĐây là yêu cầu bảo mật của macOS. Bạn có muốn khởi động lại ngay không?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Khởi động lại")
            alert.addButton(withTitle: "Để sau")

            let response = alert.runModal()
            phtvIsShowingRelaunchAlert = false

            if response == .alertFirstButtonReturn {
                NSLog("[Accessibility] User requested relaunch to apply permission")
                self.relaunchAppAfterPermissionGrant()
            } else {
                NSLog("[Accessibility] User deferred relaunch")
                self.startAccessibilityMonitoring(withInterval: 1.0, resetState: false)
                self.requestEventTapRecovery(reason: "accessibilityNeedsRelaunch", force: true)
            }
        }
    }

    func checkAccessibilityAndRestart() {
        // AXIsProcessTrusted() is the Apple-canonical gate for accessibility permission.
        // When trusted, invalidate any stale backoff so canCreateEventTap() gets a fresh
        // attempt — avoids being stuck behind exponential backoff from a propagation delay.
        guard AXIsProcessTrusted() else { return }
        PHTVManager.invalidatePermissionCache()
        if PHTVManager.canCreateEventTap() {
            performAccessibilityGrantedRestart()
        }
    }
}
