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
private let phtvTCCRepairMaxAttemptsPerSession = 3
private let phtvTCCRepairRetryCooldown: CFAbsoluteTime = 60
private let phtvAccessibilityGrantRelaunchArgument = "--phtv-relaunched-after-accessibility-grant"
private let phtvDeferredRelaunchPollIntervalSeconds = "0.2"

func phtvShouldRelaunchAfterAccessibilityGrant(
    axTrusted: Bool,
    needsRelaunchAfterPermission: Bool,
    isEventTapInitialized: Bool,
    isRelaunchAlreadyScheduled: Bool
) -> Bool {
    axTrusted
        && needsRelaunchAfterPermission
        && !isEventTapInitialized
        && !isRelaunchAlreadyScheduled
}

func phtvShouldFallbackRelaunchAfterEventTapFailures(
    accessibilityTrusted: Bool,
    isRelaunchAlreadyScheduled: Bool
) -> Bool {
    accessibilityTrusted
        && !isRelaunchAlreadyScheduled
}

func phtvShouldPerformInProcessRecovery(
    isRelaunchAlreadyScheduled: Bool
) -> Bool {
    !isRelaunchAlreadyScheduled
}

func phtvDeferredRelaunchProcessArguments(
    parentPID: Int32,
    bundlePath: String,
    launchArguments: [String]
) -> [String] {
    let script = """
    parent_pid="$1"
    bundle_path="$2"
    shift 2
    while kill -0 "$parent_pid" 2>/dev/null; do
        sleep \(phtvDeferredRelaunchPollIntervalSeconds)
    done
    sleep \(phtvDeferredRelaunchPollIntervalSeconds)
    if [ "$#" -gt 0 ]; then
        exec /usr/bin/open -n "$bundle_path" --args "$@"
    else
        exec /usr/bin/open -n "$bundle_path"
    fi
    """

    return [
        "-c",
        script,
        "sh",
        String(parentPID),
        bundlePath
    ] + launchArguments
}

@MainActor
func phtvRunAccessibilityRevokedAlert() -> NSApplication.ModalResponse {
    let alert = NSAlert()
    alert.messageText = "⚠️  Quyền trợ năng đã bị tắt!"
    alert.informativeText = "PHTV cần quyền trợ năng để hoạt động.\n\nỨng dụng sẽ tự động hoạt động lại khi bạn cấp quyền."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Mở cài đặt")
    alert.addButton(withTitle: "Đóng")
    return alert.runModal()
}

@MainActor
var phtvAccessibilityRevokedAlertRunner: @MainActor () -> NSApplication.ModalResponse = phtvRunAccessibilityRevokedAlert

func phtvShouldScheduleAutomaticTCCRepair(
    isAttempting: Bool,
    attemptsInSession: Int,
    lastAttemptTime: CFAbsoluteTime,
    now: CFAbsoluteTime,
    maxAttempts: Int = phtvTCCRepairMaxAttemptsPerSession,
    cooldown: CFAbsoluteTime = phtvTCCRepairRetryCooldown
) -> Bool {
    if isAttempting {
        return false
    }
    if attemptsInSession >= maxAttempts {
        return false
    }
    if lastAttemptTime > 0, (now - lastAttemptTime) < cooldown {
        return false
    }
    return true
}

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

        if !phtvShouldPerformInProcessRecovery(
            isRelaunchAlreadyScheduled: isRelaunchingAfterPermissionGrant
        ) {
            if statusChanged {
                NSLog(
                    "[Accessibility] Status changed while relaunch is pending; suppressing in-process recovery"
                )
            }
            wasAccessibilityEnabled = isEnabled
            return
        }

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
            if !AXIsProcessTrusted() {
                needsRelaunchAfterPermission = true
            }
            NotificationCenter.default.post(name: NotificationName.accessibilityPermissionLost, object: nil)
        } else if isEnabled {
            accessibilityStableCount += 1
        }

        wasAccessibilityEnabled = isEnabled
    }

    func performAccessibilityGrantedRestart() {
        guard phtvShouldPerformInProcessRecovery(
            isRelaunchAlreadyScheduled: isRelaunchingAfterPermissionGrant
        ) else {
            NSLog("[Accessibility] Relaunch already pending; skipping duplicate recovery")
            return
        }

        NSLog("[Accessibility] Permission granted - preparing event tap recovery...")
        PHTVManager.invalidatePermissionCache()

        if phtvShouldRelaunchAfterAccessibilityGrant(
            axTrusted: AXIsProcessTrusted(),
            needsRelaunchAfterPermission: needsRelaunchAfterPermission,
            isEventTapInitialized: PHTVManager.isInited(),
            isRelaunchAlreadyScheduled: isRelaunchingAfterPermissionGrant
        ) {
            NSLog("[Accessibility] Accessibility was granted after launch - relaunching app")
            stopAccessibilityMonitoring()
            stopHealthCheckMonitoring()
            publishTypingPermissionState(eventTapReady: false)
            relaunchAppAfterPermissionGrant()
            return
        }

        stopAccessibilityMonitoring()
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
            publishTypingPermissionState(eventTapReady: false)

            let shouldRelaunch = phtvShouldFallbackRelaunchAfterEventTapFailures(
                accessibilityTrusted: AXIsProcessTrusted(),
                isRelaunchAlreadyScheduled: isRelaunchingAfterPermissionGrant
            )

            guard shouldRelaunch else {
                NSLog("[EventTap] Failed after 3 attempts; waiting for Accessibility/session tap readiness")
                startAccessibilityMonitoring(withInterval: currentMonitoringInterval(), resetState: true)
                continuePermissionGuidanceIfNeeded()
                return
            }

            // macOS may require a process restart before the new TCC state is visible
            // to a live CGEvent tap. Restart automatically instead of asking the user.
            NSLog("[EventTap] Failed after 3 attempts with all permissions present - relaunching automatically")
            relaunchAppAfterPermissionGrant()
        }
    }

    private func onEventTapInitSuccess() {
        isAttemptingTCCRepair = false
        automaticTCCRepairAttemptCount = 0
        lastAutomaticTCCRepairAttemptTime = 0

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
        needsRelaunchAfterPermission = false
        isRelaunchingAfterPermissionGrant = false

        let showUI = UserDefaults.standard.integer(forKey: phtvDefaultsKeyShowUIOnStartup)
        if showUI == 1 {
            onControlPanelSelected()
        }
    }

    func relaunchAppAfterPermissionGrant() {
        guard !isRelaunchingAfterPermissionGrant else {
            NSLog("[Accessibility] Relaunch already scheduled; skipping duplicate request")
            return
        }

        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            NSLog("[Accessibility] Relaunch skipped: bundle URL is not an app (%@)", bundleURL.path)
            return
        }

        isRelaunchingAfterPermissionGrant = true
        let relaunchArguments = [phtvAccessibilityGrantRelaunchArgument]
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = phtvDeferredRelaunchProcessArguments(
            parentPID: ProcessInfo.processInfo.processIdentifier,
            bundlePath: bundleURL.path,
            launchArguments: relaunchArguments
        )
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.standardInput = nil

        do {
            try task.run()
            NSLog(
                "[Accessibility] Deferred relaunch helper started (pid=%d); terminating current app",
                task.processIdentifier
            )
            NSApp.terminate(nil)
        } catch {
            NSLog("[Accessibility] Failed to start deferred relaunch helper: %@", error.localizedDescription)
            isRelaunchingAfterPermissionGrant = false
            tryInitEventTap(attempt: 1)
        }
    }

    func handleAccessibilityRevoked() {
        guard !isPresentingAccessibilityRevokedAlert else {
            return
        }
        isPresentingAccessibilityRevokedAlert = true
        defer { isPresentingAccessibilityRevokedAlert = false }

        if !AXIsProcessTrusted() {
            needsRelaunchAfterPermission = true
        }

        if PHTVManager.isInited() {
            NSLog("🛑 CRITICAL: Accessibility revoked! Stopping event tap immediately...")
            PHTVManager.stopEventTap()
        }
        publishTypingPermissionState(eventTapReady: false)

        let response = phtvAccessibilityRevokedAlertRunner()
        if response == .alertFirstButtonReturn {
            PHTVAccessibilityService.openAccessibilityPreferences()
            PHTVManager.invalidatePermissionCache()
            NSLog("[Accessibility] User opening System Settings to re-grant")
        }

        attemptAutomaticTCCRepairIfNeeded()
    }

    func attemptAutomaticTCCRepairIfNeeded() {
        let now = CFAbsoluteTimeGetCurrent()
        guard phtvShouldScheduleAutomaticTCCRepair(
            isAttempting: isAttemptingTCCRepair,
            attemptsInSession: automaticTCCRepairAttemptCount,
            lastAttemptTime: lastAutomaticTCCRepairAttemptTime,
            now: now
        ) else {
#if DEBUG
            if automaticTCCRepairAttemptCount >= phtvTCCRepairMaxAttemptsPerSession {
                NSLog(
                    "[Accessibility] Skipping auto-repair: attempt limit reached (%d)",
                    automaticTCCRepairAttemptCount
                )
            }
#endif
            return
        }

        isAttemptingTCCRepair = true
        automaticTCCRepairAttemptCount += 1
        lastAutomaticTCCRepairAttemptTime = now
        let attemptIndex = automaticTCCRepairAttemptCount

#if DEBUG
        NSLog(
            "[Accessibility] Attempting automatic TCC repair (%d/%d)",
            attemptIndex,
            phtvTCCRepairMaxAttemptsPerSession
        )
#endif

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
            automaticTCCRepairAttemptCount = 0
            lastAutomaticTCCRepairAttemptTime = 0
        }
        isAttemptingTCCRepair = false
    }

    func checkAccessibilityAndRestart() {
        // AXIsProcessTrusted() is the Apple-canonical gate for accessibility permission.
        // Do NOT gate on canCreateEventTap() here: the session tap may still be settling
        // after TCC propagation even when AXIsProcessTrusted() is already true.
        guard AXIsProcessTrusted() else { return }
        guard !PHTVManager.isInited() else { return }
        PHTVManager.invalidatePermissionCache()
        performAccessibilityGrantedRestart()
    }
}
