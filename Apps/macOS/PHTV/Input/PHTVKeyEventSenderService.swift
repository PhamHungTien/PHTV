//
//  PHTVKeyEventSenderService.swift
//  PHTV
//
//  Swift implementation of keyboard event sending helpers.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import CoreGraphics
import Foundation

@objc(PHTVKeyEventSenderService)
class PHTVKeyEventSenderService: NSObject {

    // MARK: - Event source

    private final class EventSourceStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var sharedEventSource: CGEventSource?

        func set(_ source: CGEventSource?) {
            lock.lock()
            sharedEventSource = source
            lock.unlock()
        }

        func get() -> CGEventSource? {
            lock.lock()
            let source = sharedEventSource
            lock.unlock()
            return source
        }
    }

    private static let eventSourceState = EventSourceStateBox()

    @objc class func initializeEventSource() {
        eventSourceState.set(CGEventSource(stateID: .privateState))
    }

    private static var eventSource: CGEventSource? { eventSourceState.get() }

    // MARK: - Core event dispatch

    @objc class func postSyntheticEvent(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: EventSourceMarker.phtv)
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() ||
           PHTVEventRuntimeContextService.forceHIDPostEnabled() {
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
        guard EngineInputClassification.isDoubleCodeTable(PHTVEngineRuntimeFacade.currentCodeTable()) else { return }
        PHTVTypingSyncStateService.consumeSyncKeyOnBackspace()
    }

    // MARK: - Backspace

    @objc class func sendPhysicalBackspace() {
        guard let source = eventSource else { return }
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() ||
           PHTVEventRuntimeContextService.forceHIDPostEnabled() {
            guard let bsDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KeyCode.delete), keyDown: true),
                  let bsUp   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KeyCode.delete), keyDown: false) else { return }
            PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: bsDown, keyUp: bsUp, eventMarker: EventSourceMarker.phtv)
            postSyntheticEvent(bsDown)
            postSyntheticEvent(bsUp)
            PHTVTimingService.spotlightTinyDelay()
        } else {
            guard let bsDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KeyCode.delete), keyDown: true),
                  let bsUp   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KeyCode.delete), keyDown: false) else { return }
            bsDown.flags.insert(.maskNonCoalesced)
            bsUp.flags.insert(.maskNonCoalesced)
            postSyntheticEvent(bsDown)
            postSyntheticEvent(bsUp)
        }
    }

    @objc class func sendBackspace() {
        sendPhysicalBackspace()
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        guard EngineInputClassification.isDoubleCodeTable(codeTable) else { return }
        if !PHTVTypingSyncStateService.syncKeyIsEmpty() {
            if PHTVTypingSyncStateService.syncKeyBackValue() > 1 {
                if !(codeTable == Int32(CodeTable.unicodeComposite.toIndex()) &&
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

    @objc class func sendPasteShortcut() -> Bool {
        guard let source = eventSource,
              let commandDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(KeyCode.leftCommand),
                keyDown: true),
              let pasteDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(KeyCode.vKey),
                keyDown: true),
              let pasteUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(KeyCode.vKey),
                keyDown: false),
              let commandUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(KeyCode.leftCommand),
                keyDown: false) else {
            return false
        }

        commandDown.flags = .maskCommand
        pasteDown.flags = .maskCommand
        pasteUp.flags = .maskCommand
        commandUp.flags = []
        for event in [commandDown, pasteDown, pasteUp, commandUp] {
            postSyntheticEvent(event)
        }
        return true
    }

    @objc class func sendShiftAndLeftArrow() {
        guard let source = eventSource else { return }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KeyCode.leftArrow), keyDown: true),
              let up   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(KeyCode.leftArrow), keyDown: false) else { return }
        var flags = down.flags
        flags.insert(.maskShift)
        down.flags = flags
        up.flags = flags
        postSyntheticEvent(down)
        postSyntheticEvent(up)
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        if EngineInputClassification.isDoubleCodeTable(codeTable) && !PHTVTypingSyncStateService.syncKeyIsEmpty() {
            if PHTVTypingSyncStateService.syncKeyBackValue() > 1 {
                if !(codeTable == Int32(CodeTable.unicodeComposite.toIndex()) &&
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
        PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: EventSourceMarker.phtv)
        var char = ch
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
        postSyntheticEvent(down)
        postSyntheticEvent(up)
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
            PHTVTimingService.spotlightTinyDelay()
        }
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        if EngineInputClassification.isDoubleCodeTable(codeTable) {
            insertKeyLength(1)
        }
    }

    @objc class func sendKeyCode(_ data: UInt32) {
        guard let source = eventSource else { return }
        var newChar = UInt16(data & 0xFFFF)
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        let charCodeMask = EngineBitMask.charCode
        let capsMask = EngineBitMask.caps

        if (data & charCodeMask) == 0 {
            // Direct keycode case
            if EngineInputClassification.isDoubleCodeTable(codeTable) {
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
            PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: EventSourceMarker.phtv)
            postSyntheticEvent(down)
            postSyntheticEvent(up)
            if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                PHTVTimingService.spotlightTinyDelay()
            }
        } else {
            // Unicode character code case
            switch codeTable {
            case Int32(CodeTable.unicode.toIndex()): // 0 — 2-byte Unicode
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
                PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: EventSourceMarker.phtv)
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
                postSyntheticEvent(down)
                postSyntheticEvent(up)
                if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                    PHTVTimingService.spotlightTinyDelay()
                }

            case Int32(CodeTable.tcvn.toIndex()),       // 1
                 Int32(CodeTable.vniWindows.toIndex()), // 2
                 Int32(CodeTable.cp1258.toIndex()):     // 4 — 1-byte codes
                let newCharHi = UInt16(EnginePackedData.highByte(data))
                newChar = UInt16(EnginePackedData.lowByte(data))
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
                PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: EventSourceMarker.phtv)
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
                postSyntheticEvent(down)
                postSyntheticEvent(up)
                if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                    PHTVTimingService.spotlightTinyDelay()
                }
                if newCharHi > 32 {
                    if codeTable == Int32(CodeTable.vniWindows.toIndex()) {
                        insertKeyLength(2)
                    }
                    var hi = newCharHi
                    guard let down2 = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                          let up2   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
                    PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down2, keyUp: up2, eventMarker: EventSourceMarker.phtv)
                    down2.keyboardSetUnicodeString(stringLength: 1, unicodeString: &hi)
                    up2.keyboardSetUnicodeString(stringLength: 1, unicodeString: &hi)
                    postSyntheticEvent(down2)
                    postSyntheticEvent(up2)
                    if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                        PHTVTimingService.spotlightTinyDelay()
                    }
                } else {
                    if codeTable == Int32(CodeTable.vniWindows.toIndex()) {
                        insertKeyLength(1)
                    }
                }

            case Int32(CodeTable.unicodeComposite.toIndex()): // 3 — Unicode Compound
                let newCharHi = UInt16(newChar >> 13)
                newChar &= 0x1FFF
                let len = newCharHi > 0 ? 2 : 1
                insertKeyLength(Int32(len))
                let uniChars: [UInt16] = [newChar, newCharHi > 0 ? EnginePackedData.unicodeCompoundMark(at: Int32(newCharHi) - 1) : 0]
                uniChars.withUnsafeBufferPointer { chars in
                    forEachUnicodeEventPair(
                        chars: UnsafeBufferPointer(rebasing: chars[..<len]),
                        source: source,
                        bundleId: PHTVEventRuntimeContextService.effectiveTargetBundleIdValue()
                    ) { down, up in
                        postSyntheticEvent(down)
                        postSyntheticEvent(up)
                    }
                }
                if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
                    PHTVTimingService.spotlightTinyDelay()
                }

            default:
                break
            }
        }
    }

    @objc class func sendEmptyCharacter() {
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        if EngineInputClassification.isDoubleCodeTable(codeTable) {
            insertKeyLength(1)
        }
        guard let source = eventSource else { return }
        var newChar: UInt16 = 0x202F // narrow no-break space — "empty" placeholder
        if let bundleId = PHTVAppContextService.currentFrontmostBundleId(),
           PHTVAppContextService.needsNiceSpace(forBundleId: bundleId) {
            newChar = 0x200C // zero-width non-joiner
        }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        PHTVEventContextBridgeService.configureSyntheticKeyEvents(withKeyDown: down, keyUp: up, eventMarker: EventSourceMarker.phtv)
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &newChar)
        postSyntheticEvent(down)
        postSyntheticEvent(up)
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() {
            PHTVTimingService.spotlightTinyDelay()
        }
    }

    // MARK: - Chunked Unicode string

    /// Preserve the decoded output while adapting its event boundaries to the
    /// target editor. In TeXstudio, a batched restore such as "A4" is ignored
    /// after deletion has already happened (issue #224). The same restriction
    /// applies to Unicode Compound output, including step-by-step sends.
    /// TeXstudio deletes combining marks as individual UTF-16 units, so the
    /// existing sync-key lengths remain valid when those units are sent apart.
    class func forEachUnicodeEventPair(
        chars: UnsafeBufferPointer<UInt16>,
        source: CGEventSource,
        bundleId: String?,
        send: (CGEvent, CGEvent) -> Void
    ) {
        guard let baseAddress = chars.baseAddress, !chars.isEmpty else { return }
        let eventLength = PHTVAppDetectionService.needsSingleUnitUnicodeEvents(bundleId) ? 1 : chars.count
        var offset = 0
        while offset < chars.count {
            var count = min(eventLength, chars.count - offset)
            // Never create malformed UTF-16 for non-BMP macro content. The
            // editor may still reject that scalar, but splitting its surrogate
            // pair would corrupt the payload before it even reaches the app.
            if count == 1,
               (0xD800...0xDBFF).contains(chars[offset]),
               offset + 1 < chars.count,
               (0xDC00...0xDFFF).contains(chars[offset + 1]) {
                count = 2
            }
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
            PHTVEventContextBridgeService.configureSyntheticKeyEvents(
                withKeyDown: down, keyUp: up, eventMarker: EventSourceMarker.phtv)
            down.keyboardSetUnicodeString(stringLength: count, unicodeString: baseAddress + offset)
            up.keyboardSetUnicodeString(stringLength: count, unicodeString: baseAddress + offset)
            send(down, up)
            offset += count
        }
    }

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
        let bundleId = PHTVEventRuntimeContextService.effectiveTargetBundleIdValue()
        var i = 0
        while i < Int(len) {
            let chunkLen = min(effectiveChunkSize, Int(len) - i)
            forEachUnicodeEventPair(
                chars: UnsafeBufferPointer(start: chars + i, count: chunkLen),
                source: source,
                bundleId: bundleId
            ) { down, up in
                postSyntheticEvent(down)
                postSyntheticEvent(up)
            }
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

    /// Paced variant for editors that drop synthetic key events arriving
    /// back-to-back (observed in Notion code blocks / CodeMirror). Waits
    /// before the first deletion so the editor settles after the consumed
    /// keystroke, then paces each backspace and leaves a trailing delay so
    /// the replacement text does not race the final deletion.
    @objc class func sendPacedBackspaceSequence(_ count: Int32, interDelayUs: UInt32) {
        guard count > 0 else { return }
        if interDelayUs > 0 { usleep(interDelayUs) }
        for _ in 0..<count {
            sendBackspace()
            if interDelayUs > 0 { usleep(interDelayUs) }
        }
    }

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
