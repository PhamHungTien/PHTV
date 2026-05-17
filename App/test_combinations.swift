import Foundation
import CoreGraphics

func tryTap(place: CGEventTapPlacement, mask: CGEventMask, name: String) {
    print("Testing \(name):")
    let callback: CGEventTapCallBack = { _, _, event, _ in
        return Unmanaged.passUnretained(event)
    }
    
    let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: place,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: nil
    )
    
    if let tap = tap {
        print("  -> tapCreate: SUCCESS")
        CGEvent.tapEnable(tap: tap, enable: true)
        let isEnabled = CGEvent.tapIsEnabled(tap: tap)
        print("  -> tapIsEnabled: \(isEnabled)")
        CFMachPortInvalidate(tap)
    } else {
        print("  -> tapCreate: FAILED (returned nil)")
    }
}

let keyDownMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
let keyboardMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    | CGEventMask(1 << CGEventType.keyUp.rawValue)
    | CGEventMask(1 << CGEventType.flagsChanged.rawValue)

let fullMask = keyboardMask
    | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
    | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)

tryTap(place: .tailAppendEventTap, mask: keyDownMask, name: "1. tailAppend + keyDown only")
tryTap(place: .headInsertEventTap, mask: keyDownMask, name: "2. headInsert + keyDown only")
tryTap(place: .headInsertEventTap, mask: keyboardMask, name: "3. headInsert + keyboard (keyDown, keyUp, flagsChanged)")
tryTap(place: .headInsertEventTap, mask: fullMask, name: "4. headInsert + full (keyboard + mouse down)")
