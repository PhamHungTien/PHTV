//
//  PHTVEventTapService.swift
//  PHTV
//
//  Event tap lifecycle and health management.
//

import ApplicationServices
import Foundation

@objc final class PHTVEventTapService: NSObject {
    nonisolated(unsafe) private static var isInited = false
    nonisolated(unsafe) private static var permissionLost = false
    nonisolated(unsafe) private static var eventTap: CFMachPort?
    nonisolated(unsafe) private static var runLoopSource: CFRunLoopSource?
    nonisolated(unsafe) private static var tapReenableCount: UInt = 0
    nonisolated(unsafe) private static var tapRecreateCount: UInt = 0

    private static func eventMaskBit(_ type: CGEventType) -> CGEventMask {
        CGEventMask(1) << CGEventMask(type.rawValue)
    }

    @objc static func hasPermissionLost() -> Bool {
        permissionLost
    }

    @objc static func markPermissionLost() {
        permissionLost = true

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            NSLog("🛑🛑🛑 EMERGENCY: Event tap INVALIDATED due to permission loss!")
        }
    }

    @objc static func isEventTapInited() -> Bool {
        isInited
    }

    @objc static func initEventTap() -> Bool {
        if isInited {
            return true
        }

        permissionLost = false
        PHTVPermissionService.invalidatePermissionCache()

        PHTVInit()

        let mask = eventMaskBit(.keyDown)
            | eventMaskBit(.keyUp)
            | eventMaskBit(.flagsChanged)
            | eventMaskBit(.leftMouseDown)
            | eventMaskBit(.rightMouseDown)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            return PHTVCallback(proxy, type, event, refcon)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        )

        if eventTap == nil {
            NSLog("[EventTap] HID tap failed, falling back to session tap")
            eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: nil
            )
        }

        guard let tap = eventTap else {
            fputs("Failed to create event tap\n", stderr)
            return false
        }

        isInited = true

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[EventTap] Enabled and added to main run loop")
        return true
    }

    @objc static func stopEventTap() -> Bool {
        if isInited {
            NSLog("[EventTap] Stopping...")

            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: false)
            }

            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
                runLoopSource = nil
            }

            if let tap = eventTap {
                if CFMachPortIsValid(tap) {
                    CFMachPortInvalidate(tap)
                }
                eventTap = nil
            }

            isInited = false
            permissionLost = false
            NSLog("[EventTap] Stopped successfully")
        }
        return true
    }

    @objc static func handleEventTapDisabled(_ type: CGEventType) {
        if !isInited {
            return
        }

        let reason = (type == .tapDisabledByTimeout) ? "timeout" : "user input"
        NSLog("[EventTap] Disabled by %s — attempting to re-enable", reason)

        tapReenableCount += 1
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        if let tap = eventTap, !CGEvent.tapIsEnabled(tap: tap) {
            DispatchQueue.main.async {
                if !isInited {
                    return
                }
                NSLog("[EventTap] Re-enabling failed, recreating event tap")
                tapRecreateCount += 1
                _ = stopEventTap()
                _ = initEventTap()
            }
        }
    }

    @objc static func isEventTapEnabled() -> Bool {
        guard isInited, let tap = eventTap else {
            return false
        }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    @objc static func ensureEventTapAlive() {
        if !isInited {
            DispatchQueue.main.async {
                if !isInited {
                    _ = initEventTap()
                }
            }
            return
        }

        guard let tap = eventTap else {
            DispatchQueue.main.async {
                _ = initEventTap()
            }
            return
        }

        if !CGEvent.tapIsEnabled(tap: tap) {
            tapReenableCount += 1
            NSLog("[EventTap] Health check: tap disabled — re-enabling (count=%lu)", tapReenableCount)
            CGEvent.tapEnable(tap: tap, enable: true)

            if !CGEvent.tapIsEnabled(tap: tap) {
                DispatchQueue.main.async {
                    if !isInited {
                        return
                    }
                    tapRecreateCount += 1
                    NSLog("[EventTap] Health check: re-enable failed — recreating tap (count=%lu)", tapRecreateCount)
                    _ = stopEventTap()
                    _ = initEventTap()
                }
            }
        }
    }
}
