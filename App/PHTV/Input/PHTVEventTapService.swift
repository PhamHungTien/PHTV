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

@objc final class PHTVEventTapService: NSObject {
    private struct EventTapRuntimeState {
        var isInited = false
        var permissionLost = false
        var eventTap: CFMachPort?
        var runLoopSource: CFRunLoopSource?
        var mouseClickMonitor: Any?
        var usedFallbackKeyboardOnlyMask = false
        var tapReenableCount: UInt = 0
        var tapRecreateCount: UInt = 0
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

    private static func publishTypingReadiness(_ isReady: Bool) {
        guard runtimeState.shouldPublishTypingReadiness(isReady) else {
            return
        }
        NotificationCenter.default.post(
            name: NotificationName.accessibilityStatusChanged,
            object: NSNumber(value: isReady)
        )
    }

    private static func eventMaskBit(_ type: CGEventType) -> CGEventMask {
        CGEventMask(1) << CGEventMask(type.rawValue)
    }

    private static func resetTransientTapRuntimeState() {
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

        let fullMask = eventMaskBit(.keyDown)
            | eventMaskBit(.keyUp)
            | eventMaskBit(.flagsChanged)
            | eventMaskBit(.leftMouseDown)
            | eventMaskBit(.rightMouseDown)

        let keyboardOnlyMask = eventMaskBit(.keyDown)
            | eventMaskBit(.keyUp)
            | eventMaskBit(.flagsChanged)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            return PHTVEventCallbackService.handle(proxy: proxy, type: type, event: event, refcon: refcon)
        }

        // Try full mask (keyboard + mouse) first
        NSLog("[EventTap] Attempting tap creation with full mask (keyboard + mouse)...")
        var tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: fullMask,
            callback: callback,
            userInfo: nil
        )
        var usedFallback = false

        // Fallback: keyboard-only mask if full mask fails
        if tap == nil {
            NSLog("[EventTap] ⚠️ Full mask failed — falling back to keyboard-only mask")
            tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: keyboardOnlyMask,
                callback: callback,
                userInfo: nil
            )
            usedFallback = true
        }

        guard let tap else {
            NSLog("[EventTap] ❌ Both full and keyboard-only tap creation FAILED")
            publishTypingReadiness(false)
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runtimeState.withLock { state in
            state.eventTap = tap
            state.runLoopSource = source
            state.usedFallbackKeyboardOnlyMask = usedFallback
            state.isInited = true
        }

        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        let isReady = CGEvent.tapIsEnabled(tap: tap)

        if usedFallback {
            NSLog("[EventTap] ✅ Keyboard-only tap enabled — installing NSEvent mouse monitor")
            installMouseClickMonitor()
        } else {
            NSLog("[EventTap] ✅ Full tap enabled (keyboard + mouse) on main run loop")
        }

        publishTypingReadiness(isReady)
        return isReady
    }

    @objc static func stopEventTap() -> Bool {
        let (didStop, tap, source) = runtimeState.withLock { state -> (Bool, CFMachPort?, CFRunLoopSource?) in
            guard state.isInited else {
                return (false, nil, nil)
            }
            let tap = state.eventTap
            let source = state.runLoopSource
            state.runLoopSource = nil
            state.eventTap = nil
            state.isInited = false
            state.permissionLost = false
            state.usedFallbackKeyboardOnlyMask = false
            return (true, tap, source)
        }
        if didStop {
            NSLog("[EventTap] Stopping...")

            removeMouseClickMonitor()

            if let tap {
                CGEvent.tapEnable(tap: tap, enable: false)
            }

            if let source {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
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

    // MARK: - NSEvent Mouse Click Monitor (Fallback)

    private static func installMouseClickMonitor() {
        removeMouseClickMonitor()
        let monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { _ in
            PHTVEngineSessionService.requestNewSessionInternal(allowUppercasePrime: true)
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
            return state.eventTap
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        if let tap, CGEvent.tapIsEnabled(tap: tap) {
            publishTypingReadiness(true)
            return
        }

        if let tap, !CGEvent.tapIsEnabled(tap: tap) {
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
