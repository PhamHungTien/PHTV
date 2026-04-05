//
//  AppDelegate+Accessibility.swift
//  PHTV
//
//  Accessibility permission flow and monitoring.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation

private let phtvDefaultsKeyShowUIOnStartup = "ShowUIOnStartup"

private nonisolated func phtvAttemptTCCRepairInBackground() async -> (fixed: Bool, error: Error?) {
    guard PHTVManager.isTCCEntryCorrupt() else {
        return (false, nil)
    }

    NSLog("[Accessibility] ⚠️ TCC entry missing/corrupt - attempting automatic repair")

    var objcError: NSError?
    if PHTVManager.autoFixTCCEntry(withError: &objcError) {
        NSLog("[Accessibility] ✅ TCC auto-repair succeeded, restarting tccd...")
        PHTVManager.restartTCCDaemon()
        PHTVManager.invalidatePermissionCache()
        return (true, nil)
    }

    let repairError = objcError ?? NSError(
        domain: "PHTV.TCCRepair",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Automatic TCC repair failed"]
    )
    NSLog("[Accessibility] ❌ TCC auto-repair failed: %@",
          repairError.localizedDescription)
    return (false, repairError)
}


@MainActor @objc extension AppDelegate {
    @nonobjc
    func publishTypingPermissionState(eventTapReady: Bool? = nil) {
        let isReady = eventTapReady ?? (PHTVManager.isInited() && PHTVManager.isEventTapEnabled())
        if isReady {
            lastPresentedPermissionGuidanceStep = nil
        }
        guard lastPublishedTypingPermissionReady != isReady else { return }
        lastPublishedTypingPermissionReady = isReady
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

        accessibilityMonitorTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                self.checkAccessibilityStatus()
            }
        }

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
        accessibilityMonitorTask?.cancel()
        accessibilityMonitorTask = nil
#if DEBUG
        NSLog("[Accessibility] Stopped monitoring")
#endif
    }

    func startHealthCheckMonitoring() {
        stopHealthCheckMonitoring()

        healthCheckTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                self.runHealthCheck()
            }
        }
    }

    func stopHealthCheckMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
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

        stopAccessibilityMonitoring()
        PHTVManager.invalidatePermissionCache()

        tryInitEventTap(attempt: 1)
    }

    private func tryInitEventTap(attempt: Int) {
        NSLog("[EventTap] Init attempt %d/3", attempt)

        if PHTVManager.initEventTap() {
            NSLog("[EventTap] Initialized successfully on attempt %d - App ready!", attempt)
            onEventTapInitSuccess()
            return
        }

        if attempt < 3 {
            let delayMs = 100 * attempt
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(delayMs))
                guard !Task.isCancelled else { return }
                PHTVManager.invalidatePermissionCache()
                self.tryInitEventTap(attempt: attempt + 1)
            }
        } else {
            // macOS requires a process restart for the new permission to take effect
            // at the CGEvent tap level. Restart automatically instead of asking the user.
            NSLog("[EventTap] Failed to initialize after 3 attempts - relaunching automatically")
            publishTypingPermissionState(eventTapReady: false)
            relaunchAppAfterPermissionGrant()
        }
    }

    private func onEventTapInitSuccess() {
        startAccessibilityMonitoring()
        startHealthCheckMonitoring()
        startInputSourceMonitoring()
        requestEventTapRecovery(reason: "accessibilityGranted", force: true)
        EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
        runHotkeyHealthCheck(reason: "accessibility-granted")
        PHTVManager.startTCCNotificationListener()
        fillData(withAnimation: true)
        publishTypingPermissionState(eventTapReady: true)
        syncCurrentFrontmostAppContext(reason: "accessibilityGranted", forceExcludedRecheck: true)
        setQuickConvertString()

        let showUI = UserDefaults.standard.integer(forKey: phtvDefaultsKeyShowUIOnStartup)
        if showUI == 1 {
            onControlPanelSelected()
        }

        if needsRelaunchAfterPermission {
            needsRelaunchAfterPermission = false
            NSLog("[Accessibility] Initialized successfully - skipping forced relaunch")
        }
    }

    func relaunchAppAfterPermissionGrant() {
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.isEmpty {
            NSLog("[Accessibility] Relaunch skipped: bundle path missing")
            return
        }

        let bundleURL = URL(fileURLWithPath: bundlePath)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, error in
                if let error {
                    NSLog("[Accessibility] Relaunch failed: %@", error.localizedDescription)
                    return
                }
                NSLog("[Accessibility] Relaunching app to finalize permission")
                Task { @MainActor in
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

        attemptAutomaticTCCRepairIfNeeded()
    }

    func attemptAutomaticTCCRepairIfNeeded() {
        if isAttemptingTCCRepair || didAttemptTCCRepairOnce {
            return
        }
        isAttemptingTCCRepair = true

        Task(priority: .userInitiated) { [weak self] in
            let repairResult = await phtvAttemptTCCRepairInBackground()
            guard let self else { return }
            if repairResult.error == nil && !repairResult.fixed {
                self.finishPendingTCCRepairWithoutChanges()
                return
            }

            self.finishTCCRepairAttempt(fixed: repairResult.fixed)
        }
    }

    private func finishPendingTCCRepairWithoutChanges() {
        isAttemptingTCCRepair = false
    }

    private func finishTCCRepairAttempt(fixed: Bool) {
        if fixed {
            startAccessibilityMonitoring(withInterval: 0.3, resetState: true)
        }
        didAttemptTCCRepairOnce = true
        isAttemptingTCCRepair = false
    }

    func checkAccessibilityAndRestart() {
        // AXIsProcessTrusted() is the Apple-canonical gate for accessibility permission.
        // Do NOT gate on canCreateEventTap() here: CGPreflightPostEventAccess() may still
        // return false due to macOS propagation delay even when AXIsProcessTrusted() is true,
        // causing the app to silently skip initialization. If already initialized, skip.
        guard AXIsProcessTrusted() else { return }
        guard !PHTVManager.isInited() else { return }
        PHTVManager.invalidatePermissionCache()
        performAccessibilityGrantedRestart()
    }
}
