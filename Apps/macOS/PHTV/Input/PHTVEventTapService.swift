//
//  PHTVEventTapService.swift
//  PHTV
//
//  Event tap lifecycle and health management.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import ApplicationServices
import Foundation
import os

@objc final class PHTVEventTapService: NSObject {
    private struct EventTapRuntimeState {
        var isInited = false
        var permissionLost = false
        var eventTap: CFMachPort?
        var runLoopSource: CFRunLoopSource?
        /// Run loop the source was added to; it can differ from the current
        /// tap thread after an unresponsive thread was replaced.
        var sourceRunLoop: CFRunLoop?
        var mouseClickMonitor: Any?
        var tapReenableCount: UInt = 0
        var tapRecreateCount: UInt = 0
        var timeoutDisableCount: UInt = 0
        var tapThreadReplacementCount: UInt = 0
        var lastRecoveryReason: String?
    }

    private final class EventTapRuntimeStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = EventTapRuntimeState()
        private var lastPublishedTypingReadiness: Bool?

        func withLock<T>(_ body: (inout EventTapRuntimeState) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }

        func shouldPublishTypingReadiness(_ isReady: Bool) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if lastPublishedTypingReadiness == isReady {
                return false
            }
            lastPublishedTypingReadiness = isReady
            return true
        }

        func resetPermissionLossForTesting() {
            lock.lock()
            defer { lock.unlock() }
            state.permissionLost = false
            lastPublishedTypingReadiness = nil
        }
    }

    private static let runtimeState = EventTapRuntimeStateBox()

    // MARK: - Dedicated event-tap thread

    private final class TapThreadStateBox: @unchecked Sendable {
        let lock = NSLock()
        var runLoop: CFRunLoop?
    }

    private static let tapThreadState = TapThreadStateBox()

    /// Run loop of the dedicated event-tap thread, starting the thread on
    /// first use. Hosting the tap off the main run loop means UI work
    /// (settings window, Sparkle checks, pickers) can never delay keystroke
    /// processing for the whole system (issue #205). The thread lives for
    /// the app's lifetime; recovery cycles only attach/detach tap sources.
    /// Drops the current tap thread so the next tap is hosted on a new one.
    /// A thread blocked inside a callback cannot be stopped; it is abandoned
    /// and its invalidated tap no longer receives events.
    private static func abandonTapThread() {
        tapThreadState.lock.lock()
        tapThreadState.runLoop = nil
        tapThreadState.lock.unlock()
        runtimeState.withLock { $0.tapThreadReplacementCount += 1 }
        NSLog("[EventTap] Tap thread unresponsive — moving the tap to a new thread")
    }

    private static func currentTapRunLoopIfStarted() -> CFRunLoop? {
        tapThreadState.lock.lock()
        defer { tapThreadState.lock.unlock() }
        return tapThreadState.runLoop
    }

    /// Schedules a no-op block on the tap thread and waits for it to run.
    static func isTapThreadResponsive(timeout: TimeInterval = 0.3) async -> Bool {
        guard let runLoop = currentTapRunLoopIfStarted() else { return true }
        let executed = OSAllocatedUnfairLock(initialState: false)
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
            executed.withLock { $0 = true }
        }
        CFRunLoopWakeUp(runLoop)

        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while ProcessInfo.processInfo.systemUptime < deadline {
            if executed.withLock({ $0 }) { return true }
            try? await Task.sleep(for: .milliseconds(15))
        }
        return executed.withLock { $0 }
    }

    private static func tapThreadRunLoop() -> CFRunLoop {
        tapThreadState.lock.lock()
        if let existing = tapThreadState.runLoop {
            tapThreadState.lock.unlock()
            return existing
        }
        tapThreadState.lock.unlock()

        let ready = DispatchSemaphore(value: 0)
        let thread = Thread {
            let runLoop = CFRunLoopGetCurrent()
            tapThreadState.lock.lock()
            tapThreadState.runLoop = runLoop
            tapThreadState.lock.unlock()
            ready.signal()

            // A permanently attached port keeps the run loop alive across
            // tap stop/start cycles when no tap source is installed.
            RunLoop.current.add(Port(), forMode: .common)
            while true {
                RunLoop.current.run(mode: .default, before: .distantFuture)
            }
        }
        thread.name = "com.phamhungtien.phtv.eventtap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()

        tapThreadState.lock.lock()
        defer { tapThreadState.lock.unlock() }
        return tapThreadState.runLoop!
    }

    private static func publishTypingReadiness(_ isReady: Bool) {
        guard runtimeState.shouldPublishTypingReadiness(isReady) else {
            return
        }
        NotificationCenter.default.post(
            name: NotificationName.accessibilityStatusChanged,
            object: NSNumber(value: isReady)
        )
    }

    private static func resetTransientTapRuntimeState() {
        PHTVTextFocusSessionService.clear()
        PHTVModifierRuntimeStateService.resetTransientHotkeyState(
            savedLanguage: PHTVEngineRuntimeFacade.currentLanguage()
        )
        PHTVEventCallbackService.resetTransientStateForTapLifecycle()
    }

    @objc static func hasPermissionLost() -> Bool {
        runtimeState.withLock { $0.permissionLost }
    }

    static func resetPermissionLossForTesting() {
        runtimeState.resetPermissionLossForTesting()
    }

    @objc static func markPermissionLost() {
        let (tap, shouldNotify) = runtimeState.withLock { state -> (CFMachPort?, Bool) in
            let wasAlreadyLost = state.permissionLost
            state.permissionLost = true
            return (state.eventTap, !wasAlreadyLost)
        }

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            NSLog("🛑🛑🛑 EMERGENCY: Event tap INVALIDATED due to permission loss!")
        }

        publishTypingReadiness(false)
        if shouldNotify {
            NotificationCenter.default.post(name: NotificationName.accessibilityPermissionLost, object: nil)
        }
    }

    @objc static func isEventTapInited() -> Bool {
        runtimeState.withLock { $0.isInited }
    }

    @objc static func initEventTap() -> Bool {
        let existingTap = runtimeState.withLock { state -> CFMachPort? in
            guard state.isInited else {
                return nil
            }
            return state.eventTap
        }
        if let existingTap {
            if CGEvent.tapIsEnabled(tap: existingTap) {
                publishTypingReadiness(true)
                return true
            }

            NSLog("[EventTap] Existing tap is disabled - recreating")
            _ = stopEventTap()
        }

        guard PHTVPermissionService.canCreateEventTap() else {
            NSLog("[EventTap] Required TCC permissions are not ready; skipping tap creation")
            publishTypingReadiness(false)
            return false
        }

        runtimeState.withLock { $0.permissionLost = false }
        PHTVPermissionService.invalidatePermissionCache()
        resetTransientTapRuntimeState()

        PHTVEngineSessionService.boot()

        // Keep the privileged event tap focused on typing. macOS can refuse
        // or disable broader event masks during Secure Input and session
        // transitions; mouse clicks are observed separately below.
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            return PHTVEventCallbackService.handle(proxy: proxy, type: type, event: event, refcon: refcon)
        }

        NSLog("[EventTap] Attempting keyboard-only tap creation")
        let tap = CGEvent.tapCreate(
            tap: PHTVKeyboardEventTapConfiguration.location,
            place: PHTVKeyboardEventTapConfiguration.placement,
            options: PHTVKeyboardEventTapConfiguration.options,
            eventsOfInterest: PHTVKeyboardEventTapConfiguration.eventMask,
            callback: callback,
            userInfo: nil
        )

        guard let tap else {
            NSLog("[EventTap] ❌ Keyboard-only tap creation FAILED")
            publishTypingReadiness(false)
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let tapRunLoop = tapThreadRunLoop()
        runtimeState.withLock { state in
            state.eventTap = tap
            state.runLoopSource = source
            state.sourceRunLoop = source == nil ? nil : tapRunLoop
            state.isInited = true
        }

        if let source {
            CFRunLoopAddSource(tapRunLoop, source, CFRunLoopMode.commonModes)
            CFRunLoopWakeUp(tapRunLoop)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        let isReady = CGEvent.tapIsEnabled(tap: tap)

        if isReady {
            NSLog("[EventTap] ✅ Keyboard-only tap enabled — installing NSEvent mouse monitor")
            installMouseClickMonitor()
            Task { @MainActor in
                PHTVEventTapWatchdogService.start()
            }
        } else {
            NSLog("[EventTap] ⚠️ Keyboard-only tap was created but could not be enabled")
            // Do not leave an initialized-but-disabled tap behind. Clean up the
            // source and port so recovery always retries from a known state.
            _ = stopEventTap()
        }

        publishTypingReadiness(isReady)
        return isReady
    }

    @objc static func stopEventTap() -> Bool {
        let (didStop, tap, source, sourceRunLoop) = runtimeState.withLock {
            state -> (Bool, CFMachPort?, CFRunLoopSource?, CFRunLoop?) in
            guard state.isInited else {
                return (false, nil, nil, nil)
            }
            let tap = state.eventTap
            let source = state.runLoopSource
            let sourceRunLoop = state.sourceRunLoop
            state.runLoopSource = nil
            state.sourceRunLoop = nil
            state.eventTap = nil
            state.isInited = false
            state.permissionLost = false
            return (true, tap, source, sourceRunLoop)
        }
        if didStop {
            NSLog("[EventTap] Stopping...")

            removeMouseClickMonitor()

            if let tap {
                CGEvent.tapEnable(tap: tap, enable: false)
            }

            if let source, let sourceRunLoop {
                CFRunLoopRemoveSource(sourceRunLoop, source, CFRunLoopMode.commonModes)
                CFRunLoopWakeUp(sourceRunLoop)
            }

            if let tap, CFMachPortIsValid(tap) {
                CFMachPortInvalidate(tap)
            }

            resetTransientTapRuntimeState()
            NSLog("[EventTap] Stopped successfully")
        }
        if didStop {
            publishTypingReadiness(false)
        }
        return true
    }

    // MARK: - NSEvent Mouse Click Monitor

    private static func installMouseClickMonitor() {
        removeMouseClickMonitor()
        let monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { _ in
            PHTVEngineSessionService.requestNewSessionInternal(allowUppercasePrime: true)
            PHTVModifierRuntimeStateService.setSingleModifierSwitchPressedKeyValue(0)
            PHTVModifierRuntimeStateService.setKeyPressedWhileSingleModifierHeldValue(false)
        }
        runtimeState.withLock { state in
            state.mouseClickMonitor = monitor
        }
        NSLog("[EventTap] NSEvent mouse click monitor installed")
    }

    private static func removeMouseClickMonitor() {
        let monitor = runtimeState.withLock { state -> Any? in
            let m = state.mouseClickMonitor
            state.mouseClickMonitor = nil
            return m
        }
        if let monitor {
            NSEvent.removeMonitor(monitor)
            NSLog("[EventTap] NSEvent mouse click monitor removed")
        }
    }

    @objc static func handleEventTapDisabled(_ type: CGEventType) {
        if !runtimeState.withLock({ $0.isInited }) {
            return
        }

        let reason = (type == .tapDisabledByTimeout) ? "timeout" : "user input"
        NSLog("[EventTap] Disabled by %@ — attempting to re-enable", reason)

        let tap = runtimeState.withLock { state -> CFMachPort? in
            state.tapReenableCount += 1
            if type == .tapDisabledByTimeout {
                state.timeoutDisableCount += 1
            }
            return state.eventTap
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        if let tap, CGEvent.tapIsEnabled(tap: tap) {
            publishTypingReadiness(true)
            return
        }

        Task { @MainActor in
            if !runtimeState.withLock({ $0.isInited }) {
                return
            }
            NSLog("[EventTap] Re-enabling failed, recreating event tap")
            runtimeState.withLock { $0.tapRecreateCount += 1 }
            _ = stopEventTap()
            _ = initEventTap()
        }
    }

    @objc static func isEventTapEnabled() -> Bool {
        let (isInited, tap) = runtimeState.withLock { state in
            (state.isInited, state.eventTap)
        }
        guard isInited, let tap else {
            return false
        }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    // MARK: - In-process recovery

    struct DiagnosticSnapshot {
        let reenableCount: UInt
        let recreateCount: UInt
        let timeoutDisableCount: UInt
        let tapThreadReplacementCount: UInt
        let watchdogRecoveryCount: Int
        let watchdogActive: Bool
        let lastRecoveryReason: String?

        var reportDescription: String {
            var text = "re-enable \(reenableCount), rebuild \(recreateCount), timeout \(timeoutDisableCount), " +
                "thread \(tapThreadReplacementCount), watchdog \(watchdogActive ? "on" : "off")/\(watchdogRecoveryCount)"
            if let lastRecoveryReason {
                text += ", last: \(lastRecoveryReason)"
            }
            return text
        }
    }

    static func diagnosticSnapshot() -> DiagnosticSnapshot {
        runtimeState.withLock { state in
            DiagnosticSnapshot(
                reenableCount: state.tapReenableCount,
                recreateCount: state.tapRecreateCount,
                timeoutDisableCount: state.timeoutDisableCount,
                tapThreadReplacementCount: state.tapThreadReplacementCount,
                watchdogRecoveryCount: PHTVEventTapWatchdogService.recoveryCount,
                watchdogActive: PHTVEventTapWatchdogService.isObservingSnapshot,
                lastRecoveryReason: state.lastRecoveryReason
            )
        }
    }

    @MainActor private static var isRebuilding = false
    @MainActor private static var unresponsiveThreadChecks = 0

    /// Keystrokes reached apps without passing through the tap. Typing would
    /// stay unaccented until the tap is back, so re-enable it, or rebuild it
    /// (on a fresh thread when the current one is stuck) without relaunching.
    @MainActor
    static func recoverFromMissedKeystrokes() {
        guard AXIsProcessTrusted(), PHTVSecureInputService.isSessionOnConsole() else {
            return
        }
        // The engine buffer no longer matches the text on screen.
        PHTVEngineSessionService.requestNewSessionInternal(allowUppercasePrime: false)

        let (isInited, tap) = runtimeState.withLock { state in
            state.lastRecoveryReason = "missed keystrokes"
            return (state.isInited, state.eventTap)
        }
        if isInited, let tap, !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            if CGEvent.tapIsEnabled(tap: tap) {
                NSLog("[EventTap] Watchdog: re-enabled a disabled tap")
                publishTypingReadiness(true)
                return
            }
        }
        rebuildTap(reason: "watchdog")
    }

    /// Rebuilds the keyboard tap in-process. Used by the watchdog, the
    /// periodic thread check and the menu bar "Làm mới bộ gõ" action.
    @MainActor
    static func rebuildTap(reason: String) {
        if isRebuilding {
            return
        }
        isRebuilding = true

        Task { @MainActor in
            defer { isRebuilding = false }
            if !(await isTapThreadResponsive()) {
                abandonTapThread()
            }
            runtimeState.withLock {
                $0.tapRecreateCount += 1
                $0.lastRecoveryReason = reason
            }
            NSLog("[EventTap] Rebuilding tap (%@)", reason)
            _ = stopEventTap()
            let ready = initEventTap()
            if ready {
                PHTVEngineSessionService.requestNewSessionInternal(allowUppercasePrime: false)
            }
            NotificationCenter.default.post(
                name: NotificationName.eventTapRebuilt,
                object: NSNumber(value: ready)
            )
        }
    }

    /// Called from the periodic health check. A tap thread that misses two
    /// consecutive heartbeats is stuck in a callback; macOS then disables the
    /// tap by timeout over and over and re-enabling cannot help.
    @MainActor
    static func verifyTapThreadHealth() async {
        guard runtimeState.withLock({ $0.isInited }) else { return }
        let responsive = await isTapThreadResponsive()
        if responsive {
            unresponsiveThreadChecks = 0
            return
        }
        unresponsiveThreadChecks += 1
        if unresponsiveThreadChecks >= 2 {
            unresponsiveThreadChecks = 0
            rebuildTap(reason: "tap thread unresponsive")
        }
    }

    @objc static func ensureEventTapAlive() {
        if !runtimeState.withLock({ $0.isInited }) {
            Task { @MainActor in
                if !runtimeState.withLock({ $0.isInited }) {
                    _ = initEventTap()
                }
            }
            return
        }

        guard let tap = runtimeState.withLock({ $0.eventTap }) else {
            Task { @MainActor in
                _ = initEventTap()
            }
            return
        }

        if !CGEvent.tapIsEnabled(tap: tap) {
            let tapReenableCount = runtimeState.withLock { state -> UInt in
                state.tapReenableCount += 1
                return state.tapReenableCount
            }
            NSLog("[EventTap] Health check: tap disabled — re-enabling (count=%lu)", tapReenableCount)
            CGEvent.tapEnable(tap: tap, enable: true)

            if CGEvent.tapIsEnabled(tap: tap) {
                publishTypingReadiness(true)
            } else {
                Task { @MainActor in
                    if !runtimeState.withLock({ $0.isInited }) {
                        return
                    }
                    let tapRecreateCount = runtimeState.withLock { state -> UInt in
                        state.tapRecreateCount += 1
                        return state.tapRecreateCount
                    }
                    NSLog("[EventTap] Health check: re-enable failed — recreating tap (count=%lu)", tapRecreateCount)
                    _ = stopEventTap()
                    _ = initEventTap()
                }
            }
        }
    }
}
