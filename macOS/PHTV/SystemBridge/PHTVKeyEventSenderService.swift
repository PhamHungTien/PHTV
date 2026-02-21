//
//  PHTVKeyEventSenderService.swift
//  PHTV
//
//  Swift implementation of keyboard event sending helpers.
//  Migrated from PHTV.mm — all Send* helpers live here.
//

import CoreGraphics
import Foundation

@objc(PHTVKeyEventSenderService)
class PHTVKeyEventSenderService: NSObject {

    // MARK: - Event source

    nonisolated(unsafe) private static var sharedEventSource: CGEventSource?

    @objc class func initializeEventSource() {
        sharedEventSource = CGEventSource(stateID: .privateState)
    }

    private static var eventSource: CGEventSource? { sharedEventSource }

    // MARK: - Core event dispatch

    @objc class func postSyntheticEvent(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: phtvEventMarkerValue())
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
            event.post(tap: .cghidEventTap)
        } else if PHTVEventRuntimeContextService.postToSessionForCliEnabled() {
            event.post(tap: .cgSessionEventTap)
        } else {
            let proxyRaw = PHTVEventRuntimeContextService.eventTapProxyRawValue()
            let proxy = UnsafeMutableRawPointer(bitPattern: UInt(proxyRaw)).map { OpaquePointer($0) }
            event.tapPostEvent(proxy)
        }
    }

    // MARK: - Sync key helpers

    @objc class func insertKeyLength(_ len: Int32) {
        PHTVTypingSyncStateService.appendSyncKeyLength(len)
    }

    @objc class func consumeSyncKeyOnBackspace() {
        guard phtvRuntimeIsDoubleCode(phtvRuntimeCurrentCodeTable()) else { return }
        PHTVTypingSyncStateService.consumeSyncKeyOnBackspace()
    }

    // MARK: - Backspace

    @objc class func sendPhysicalBackspace() {
        guard let source = eventSource else { return }
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
            guard let bsDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KEY_DELETE.rawValue), keyDown: true),
                  let bsUp   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KEY_DELETE.rawValue), keyDown: false) else { return }
            PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: bsDown, keyUp: bsUp, eventMarker: phtvEventMarkerValue())
            postSyntheticEvent(bsDown)
            postSyntheticEvent(bsUp)
            PHTVTimingService.spotlightTinyDelay()
        } else {
            guard let bsDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KEY_DELETE.rawValue), keyDown: true),
                  let bsUp   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KEY_DELETE.rawValue), keyDown: false) else { return }
            bsDown.flags.insert(.maskNonCoalesced)
            bsUp.flags.insert(.maskNonCoalesced)
            postSyntheticEvent(bsDown)
            postSyntheticEvent(bsUp)
        }
    }

    @objc class func sendBackspace() {
        sendPhysicalBackspace()
        let codeTable = phtvRuntimeCurrentCodeTable()
        guard phtvRuntimeIsDoubleCode(codeTable) else { return }
        if !PHTVTypingSyncStateService.syncKeyIsEmpty() {
            if PHTVTypingSyncStateService.syncKeyBackValue() > 1 {
                if !(codeTable == PHTVCodeTableUnicodeComposite.rawValue &&
                     PHTVEventRuntimeContextService.appContainsUnicodeCompound()) {
                    sendPhysicalBackspace()
                }
            }
            PHTVTypingSyncStateService.popSyncKeyIfAny()
        }
    }

    // MARK: - Virtual key

    @objc class func sendVirtualKey(_ vKey: UInt8) {
        guard let source = eventSource else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(vKey), keyDown: true),
              let up   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(vKey), keyDown: false) else { return }
        postSyntheticEvent(down)
        postSyntheticEvent(up)
    }

    @objc class func sendShiftAndLeftArrow() {
        guard let source = eventSource else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KEY_LEFT.rawValue), keyDown: true),
              let up   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KEY_LEFT.rawValue), keyDown: false) else { return }
        var flags = down.flags
        flags.insert(.maskShift)
        down.flags = flags
        up.flags = flags
        postSyntheticEvent(down)
        postSyntheticEvent(up)
        let codeTable = phtvRuntimeCurrentCodeTable()
        if phtvRuntimeIsDoubleCode(codeTable) && !PHTVTypingSyncStateService.syncKeyIsEmpty() {
            if PHTVTypingSyncStateService.syncKeyBackValue() > 1 {
                if !(codeTable == PHTVCodeTableUnicodeComposite.rawValue &&
                     PHTVEventRuntimeContextService.appContainsUnicodeCompound()) {
                    postSyntheticEvent(down)
                    postSyntheticEvent(up)
                }
            }
            PHTVTypingSyncStateService.popSyncKeyIfAny()
        }
    }

    // MARK: - Character sending

    @objc class func sendPureCharacter(_ ch: UInt16) {
        guard let source = eventSource else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: phtvEventMarkerValue())
        var char = ch
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
        postSyntheticEvent(down)
        postSyntheticEvent(up)
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
            PHTVTimingService.spotlightTinyDelay()
        }
        let codeTable = phtvRuntimeCurrentCodeTable()
        if phtvRuntimeIsDoubleCode(codeTable) {
            insertKeyLength(1)
        }
    }

    @objc class func sendKeyCode(_ data: UInt32) {
        guard let source = eventSource else { return }
        var newChar = UInt16(data & 0xFFFF)
        let codeTable = phtvRuntimeCurrentCodeTable()
        let charCodeMask = phtvEngineCharCodeMask()
        let capsMask = phtvEngineCapsMask()

        if (data & charCodeMask) == 0 {
            // Direct keycode case
            if phtvRuntimeIsDoubleCode(codeTable) {
                insertKeyLength(1)
            }
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(newChar), keyDown: true),
                  let up   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(newChar), keyDown: false) else { return }
            var flags = down.flags
            if (data & capsMask) != 0 {
                flags.insert(.maskShift)
            } else {
                flags.remove(.maskShift)
            }
            flags.insert(.maskNonCoalesced)
            flags.remove(.maskSecondaryFn)
            down.flags = flags
            PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: phtvEventMarkerValue())
            postSyntheticEvent(down)
            postSyntheticEvent(up)
            if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                PHTVTimingService.spotlightTinyDelay()
            }
        } else {
            // Unicode character code case
            switch codeTable {
            case PHTVCodeTableUnicode.rawValue: // 0 — 2-byte Unicode
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
                PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: phtvEventMarkerValue())
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
                postSyntheticEvent(down)
                postSyntheticEvent(up)
                if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                    PHTVTimingService.spotlightTinyDelay()
                }

            case PHTVCodeTableTCVN3.rawValue,    // 1
                 PHTVCodeTableVNIWindows.rawValue, // 2
                 PHTVCodeTableCP1258.rawValue:     // 4 — 1-byte codes
                let newCharHi = UInt16(phtvEngineHiByte(data))
                newChar = UInt16(phtvEngineLowByte(data))
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
                PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: phtvEventMarkerValue())
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
                postSyntheticEvent(down)
                postSyntheticEvent(up)
                if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                    PHTVTimingService.spotlightTinyDelay()
                }
                if newCharHi > 32 {
                    if codeTable == PHTVCodeTableVNIWindows.rawValue {
                        insertKeyLength(2)
                    }
                    var hi = newCharHi
                    guard let down2 = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                          let up2   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
                    PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down2, keyUp: up2, eventMarker: phtvEventMarkerValue())
                    down2.keyboardSetUnicodeString(stringLength: 1, unicodeString: &hi)
                    up2.keyboardSetUnicodeString(stringLength: 1, unicodeString: &hi)
                    postSyntheticEvent(down2)
                    postSyntheticEvent(up2)
                    if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                        PHTVTimingService.spotlightTinyDelay()
                    }
                } else {
                    if codeTable == PHTVCodeTableVNIWindows.rawValue {
                        insertKeyLength(1)
                    }
                }

            case PHTVCodeTableUnicodeComposite.rawValue: // 3 — Unicode Compound
                let newCharHi = UInt16(newChar >> 13)
                newChar &= 0x1FFF
                let len = newCharHi > 0 ? 2 : 1
                insertKeyLength(Int32(len))
                var uniChars: [UInt16] = [newChar, newCharHi > 0 ? phtvEngineUnicodeCompoundMarkAt(Int32(newCharHi) - 1) : 0]
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
                PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: phtvEventMarkerValue())
                down.keyboardSetUnicodeString(stringLength: len, unicodeString: &uniChars)
                up.keyboardSetUnicodeString(stringLength: len, unicodeString: &uniChars)
                postSyntheticEvent(down)
                postSyntheticEvent(up)
                if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                    PHTVTimingService.spotlightTinyDelay()
                }

            default:
                break
            }
        }
    }

    @objc class func sendEmptyCharacter() {
        let codeTable = phtvRuntimeCurrentCodeTable()
        if phtvRuntimeIsDoubleCode(codeTable) {
            insertKeyLength(1)
        }
        guard let source = eventSource else { return }
        var newChar: UInt16 = 0x202F // narrow no-break space — "empty" placeholder
        if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           PHTVAppContextService.needsNiceSpace(forBundleId: bundleId) {
            newChar = 0x200C // zero-width non-joiner
        }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: phtvEventMarkerValue())
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
        postSyntheticEvent(down)
        postSyntheticEvent(up)
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
            PHTVTimingService.spotlightTinyDelay()
        }
    }

    // MARK: - Chunked Unicode string

    @objc class func sendUnicodeStringChunked(_ chars: UnsafePointer<UInt16>,
                                              len: Int32,
                                              chunkSize: Int32,
                                              interDelayUs: UInt64) {
        guard len > 0 else { return }
        guard let source = eventSource else { return }
        let effectiveChunkSize = max(1, Int(chunkSize))
        let cliSpeedFactor = PHTVCliRuntimeStateService.currentSpeedFactor()
        let cliPostSendBlockUs = PHTVCliRuntimeStateService.cliPostSendBlockUs()
        let isCliTarget = PHTVEventRuntimeContextService.isCliTargetEnabled()
        var effectiveDelayUs = interDelayUs
        if isCliTarget && interDelayUs > 0 {
            effectiveDelayUs = PHTVTimingService.scaleDelayMicroseconds(interDelayUs, factor: cliSpeedFactor)
        }
        if isCliTarget {
            var totalBlockUs = PHTVTimingService.scaleDelayMicroseconds(cliPostSendBlockUs, factor: cliSpeedFactor)
            if effectiveDelayUs > 0 && len > 1 {
                totalBlockUs += effectiveDelayUs * UInt64(len - 1)
            }
            PHTVCliRuntimeStateService.scheduleBlock(forMicroseconds: totalBlockUs, nowMachTime: mach_absolute_time())
        }
        var i = 0
        while i < Int(len) {
            let chunkLen = min(effectiveChunkSize, Int(len) - i)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { break }
            PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: phtvEventMarkerValue())
            down.keyboardSetUnicodeString(stringLength: chunkLen, unicodeString: chars + i)
            up.keyboardSetUnicodeString(stringLength: chunkLen, unicodeString: chars + i)
            postSyntheticEvent(down)
            postSyntheticEvent(up)
            if effectiveDelayUs > 0 && (i + effectiveChunkSize) < Int(len) {
                usleep(PHTVTimingService.clampToUseconds(effectiveDelayUs))
            }
            i += effectiveChunkSize
        }
        if isCliTarget {
            var totalBlockUs = PHTVTimingService.scaleDelayMicroseconds(cliPostSendBlockUs, factor: cliSpeedFactor)
            if effectiveDelayUs > 0 && len > 1 {
                totalBlockUs += effectiveDelayUs * UInt64(len - 1)
            }
            PHTVCliRuntimeStateService.scheduleBlock(forMicroseconds: totalBlockUs, nowMachTime: mach_absolute_time())
        }
    }

    // MARK: - Backspace sequence

    @objc class func sendBackspaceSequenceWithDelay(_ count: Int32) {
        guard count > 0 else { return }
        if PHTVEventRuntimeContextService.isCliTargetEnabled() {
            let cliSpeedFactor = PHTVCliRuntimeStateService.currentSpeedFactor()
            let cliBackspaceDelayUs = PHTVCliRuntimeStateService.cliBackspaceDelayUs()
            let cliWaitAfterBackspaceUs = PHTVCliRuntimeStateService.cliWaitAfterBackspaceUs()
            let cliPostSendBlockUs = PHTVCliRuntimeStateService.cliPostSendBlockUs()
            let backspaceDelay = PHTVTimingService.scaleDelayUseconds(PHTVTimingService.clampToUseconds(cliBackspaceDelayUs), factor: cliSpeedFactor)
            let waitDelay = PHTVTimingService.scaleDelayUseconds(PHTVTimingService.clampToUseconds(cliWaitAfterBackspaceUs), factor: cliSpeedFactor)
            var totalBlockUs = PHTVTimingService.scaleDelayMicroseconds(cliPostSendBlockUs, factor: cliSpeedFactor)
            if backspaceDelay > 0 {
                totalBlockUs += UInt64(backspaceDelay) * UInt64(count)
            }
            totalBlockUs += UInt64(waitDelay)
            PHTVCliRuntimeStateService.scheduleBlock(forMicroseconds: totalBlockUs, nowMachTime: mach_absolute_time())
            if cliSpeedFactor > 1.05 {
                let preDelay = PHTVTimingService.scaleDelayUseconds(4000, factor: cliSpeedFactor)
                if preDelay > 0 { usleep(preDelay) }
            }
            for _ in 0..<count {
                sendPhysicalBackspace()
                consumeSyncKeyOnBackspace()
                if backspaceDelay > 0 { usleep(backspaceDelay) }
            }
            if waitDelay > 0 { usleep(waitDelay) }
            PHTVCliRuntimeStateService.scheduleBlock(forMicroseconds: totalBlockUs, nowMachTime: mach_absolute_time())
            return
        }
        for _ in 0..<count {
            sendBackspace()
        }
    }
}
