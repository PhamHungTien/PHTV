//
//  PHTVEventTapService.swift
//  PHTV
//
//  Event tap lifecycle and health management.
//

import ApplicationServices
import Foundation

@objc final class PHTVEventTapService: NSObject {
    private struct EventTapRuntimeState {
        var isInited = false
        var permissionLost = false
        var eventTap: CFMachPort?
        var runLoopSource: CFRunLoopSource?
        var tapReenableCount: UInt = 0
        var tapRecreateCount: UInt = 0
    }

    private final class EventTapRuntimeStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = EventTapRuntimeState()

        func withLock<T>(_ body: (inout EventTapRuntimeState) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    private static let runtimeState = EventTapRuntimeStateBox()

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

    @objc static func markPermissionLost() {
        let tap = runtimeState.withLock { state -> CFMachPort? in
            state.permissionLost = true
            return state.eventTap
        }

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            NSLog("🛑🛑🛑 EMERGENCY: Event tap INVALIDATED due to permission loss!")
        }
    }

    @objc static func isEventTapInited() -> Bool {
        runtimeState.withLock { $0.isInited }
    }

    @objc static func initEventTap() -> Bool {
        if runtimeState.withLock({ $0.isInited }) {
            return true
        }

        runtimeState.withLock { $0.permissionLost = false }
        PHTVPermissionService.invalidatePermissionCache()
        resetTransientTapRuntimeState()

        PHTVEngineSessionService.boot()

        let mask = eventMaskBit(.keyDown)
            | eventMaskBit(.keyUp)
            | eventMaskBit(.flagsChanged)
            | eventMaskBit(.leftMouseDown)
            | eventMaskBit(.rightMouseDown)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            return PHTVEventCallbackService.handle(proxy: proxy, type: type, event: event, refcon: refcon)
        }

        var createdTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        )

        if createdTap == nil {
            NSLog("[EventTap] HID tap failed, falling back to session tap")
            createdTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: nil
            )
        }

        guard let tap = createdTap else {
            fputs("Failed to create event tap\n", stderr)
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runtimeState.withLock { state in
            state.eventTap = tap
            state.runLoopSource = source
            state.isInited = true
        }

        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[EventTap] Enabled and added to main run loop")
        return true
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
            return (true, tap, source)
        }
        if didStop {
            NSLog("[EventTap] Stopping...")

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
        return true
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

        if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            DispatchQueue.main.async {
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
            DispatchQueue.main.async {
                if !runtimeState.withLock({ $0.isInited }) {
                    _ = initEventTap()
                }
            }
            return
        }

        guard let tap = runtimeState.withLock({ $0.eventTap }) else {
            DispatchQueue.main.async {
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

            if !CGEvent.tapIsEnabled(tap: tap) {
                DispatchQueue.main.async {
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
