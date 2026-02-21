//
//  PHTVCharacterOutputService.swift
//  PHTV
//
//  Character output logic: sendNewCharString and handleMacro.
//  Migrated from PHTV.mm.
//

import CoreGraphics
import Darwin
import Foundation

private let kSpotlightCacheDurationMs: UInt64 = 150

@objc(PHTVCharacterOutputService)
final class PHTVCharacterOutputService: NSObject {

    // MARK: - SendNewCharString

    @objc(sendNewCharStringWithDataFromMacro:offset:keycode:flags:)
    class func sendNewCharString(dataFromMacro: Bool,
                                 offset: UInt16,
                                 keycode: UInt16,
                                 flags: UInt64) {
        let maxBuf = 20
        var outputIndex = 0
        var loopIndex = 0
        var newCharSize = dataFromMacro
            ? Int(PHTVEngineRuntimeFacade.engineDataMacroDataSize())
            : Int(PHTVEngineRuntimeFacade.engineDataNewCharCount())
        var newCharString = [UInt16](repeating: 0, count: maxBuf)
        var willContinueSending = false
        var willSendControlKey = false

        let codeTable = Int(PHTVEngineRuntimeFacade.currentCodeTable())
        let isSpotlightTarget = PHTVEventRuntimeContextService.postToHIDTapEnabled()
                             || PHTVEventRuntimeContextService.appIsSpotlightLike()
        let isPrecomposedBatched = PHTVEventRuntimeContextService.appNeedsPrecomposedBatched()
        let forcePrecomposed = ((codeTable == 3) && isSpotlightTarget)
                            || ((codeTable == 0 || codeTable == 3) && isPrecomposedBatched)

        let pureCharMask = EngineBitMask.pureCharacter
        let charCodeMask = EngineBitMask.charCode

        if newCharSize > 0 {
            if dataFromMacro {
                loopIndex = Int(offset)
                while loopIndex < Int(PHTVEngineRuntimeFacade.engineDataMacroDataSize()) {
                    if outputIndex >= 16 { willContinueSending = true; break }
                    let tempChar = PHTVEngineRuntimeFacade.engineDataMacroDataAt(Int32(loopIndex))
                    buildChar(tempChar, codeTable: codeTable,
                              pureCharMask: pureCharMask, charCodeMask: charCodeMask,
                              into: &newCharString,
                              outputIndex: &outputIndex, newCharSize: &newCharSize)
                    loopIndex += 1
                }
            } else {
                loopIndex = Int(PHTVEngineRuntimeFacade.engineDataNewCharCount()) - 1 - Int(offset)
                while loopIndex >= 0 {
                    if outputIndex >= 16 { willContinueSending = true; break }
                    let tempChar = PHTVEngineRuntimeFacade.engineDataCharAt(Int32(loopIndex))
                    buildChar(tempChar, codeTable: codeTable,
                              pureCharMask: pureCharMask, charCodeMask: charCodeMask,
                              into: &newCharString,
                              outputIndex: &outputIndex, newCharSize: &newCharSize)
                    loopIndex -= 1
                }
            }
        }

        let engineCode = Int(PHTVEngineRuntimeFacade.engineDataCode())
        let vRestoreCode = Int(PHTVEngineRuntimeFacade.engineRestoreCode())
        let vRestoreNewCode = Int(PHTVEngineRuntimeFacade.engineRestoreAndStartNewSessionCode())
        let capsMask = EngineBitMask.caps

        if !willContinueSending && (engineCode == vRestoreCode || engineCode == vRestoreNewCode) {
            if PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(UInt32(keycode)) != 0 {
                let hasCaps = (flags & CGEventFlags.maskAlphaShift.rawValue) != 0
                           || (flags & CGEventFlags.maskShift.rawValue) != 0
                let withCaps = UInt32(keycode) | (hasCaps ? capsMask : 0)
                newCharString[outputIndex] = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(withCaps)
                outputIndex += 1
                newCharSize += 1
            } else {
                willSendControlKey = true
            }
        }
        if !willContinueSending && engineCode == vRestoreNewCode {
            PHTVEngineDataBridge.startNewSession()
        }

        let finalCharSize = willContinueSending ? 16 : outputIndex
        var finalChars = [UInt16](repeating: 0, count: maxBuf)
        var actualFinalSize = finalCharSize

        if forcePrecomposed && finalCharSize > 0 {
            let raw = String(decoding: newCharString[0..<finalCharSize], as: UTF16.self)
            let precomposed = raw.precomposedStringWithCanonicalMapping
            let precomposedUtf16 = Array(precomposed.utf16)
            actualFinalSize = min(precomposedUtf16.count, maxBuf)
            for i in 0..<actualFinalSize { finalChars[i] = precomposedUtf16[i] }
        } else {
            for i in 0..<finalCharSize { finalChars[i] = newCharString[i] }
        }

        finalChars.withUnsafeBufferPointer { buf in
            let ptr = buf.baseAddress!
            if isSpotlightTarget {
                let insertStr = String(
                    decoding: UnsafeBufferPointer(start: ptr, count: actualFinalSize),
                    as: UTF16.self)
                let backspaceCount = PHTVEventRuntimeContextService.takePendingBackspaceCount()
                let axSucceeded = PHTVEventContextBridgeService.replaceFocusedTextViaAX(
                    backspaceCount: backspaceCount,
                    insertText: insertStr,
                    verify: backspaceCount > 0,
                    safeMode: PHTVEngineRuntimeFacade.safeModeEnabled())
                if !axSucceeded {
                    PHTVKeyEventSenderService.sendBackspaceSequenceWithDelay(backspaceCount)
                    PHTVKeyEventSenderService.sendUnicodeStringChunked(
                        ptr, len: Int32(actualFinalSize),
                        chunkSize: Int32(actualFinalSize), interDelayUs: 0)
                }
            } else if PHTVEventRuntimeContextService.isCliTargetEnabled() {
                let chunkSize = max(1, PHTVCliRuntimeStateService.cliTextChunkSize())
                PHTVKeyEventSenderService.sendUnicodeStringChunked(
                    ptr, len: Int32(actualFinalSize),
                    chunkSize: chunkSize,
                    interDelayUs: PHTVCliRuntimeStateService.cliTextDelayUs())
            } else {
                PHTVKeyEventSenderService.sendUnicodeStringChunked(
                    ptr, len: Int32(actualFinalSize),
                    chunkSize: Int32(actualFinalSize), interDelayUs: 0)
            }
        }

        if willContinueSending {
            let nextOffset: UInt16 = dataFromMacro ? UInt16(loopIndex) : 16
            sendNewCharString(dataFromMacro: dataFromMacro,
                              offset: nextOffset, keycode: keycode, flags: flags)
        }
        if willSendControlKey {
            PHTVKeyEventSenderService.sendKeyCode(UInt32(keycode))
        }
    }

    // MARK: - handleMacro

    @objc(handleMacroWithKeycode:flags:)
    class func handleMacro(keycode: UInt16, flags: UInt64) {
        var effectiveTarget = PHTVEventRuntimeContextService.effectiveTargetBundleIdValue()
        if effectiveTarget == nil {
            effectiveTarget = PHTVAppContextService.focusedBundleId(
                forSafeMode: PHTVEngineRuntimeFacade.safeModeEnabled(),
                cacheDurationMs: kSpotlightCacheDurationMs)
            if effectiveTarget == nil {
                effectiveTarget = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            }
        }

        let macroPlan = PHTVInputStrategyService.macroPlan(
            forPostToHIDTap: PHTVEventRuntimeContextService.postToHIDTapEnabled(),
            appIsSpotlightLike: PHTVEventRuntimeContextService.appIsSpotlightLike(),
            browserFixEnabled: PHTVEngineRuntimeFacade.fixRecommendBrowser() != 0,
            originalBackspaceCount: Int32(PHTVEngineRuntimeFacade.engineDataBackspaceCount()),
            cliTarget: PHTVEventRuntimeContextService.isCliTargetEnabled(),
            globalStepByStep: PHTVEngineRuntimeFacade.isSendKeyStepByStepEnabled(),
            appNeedsStepByStep: PHTVEventRuntimeContextService.appNeedsStepByStep())

        let isSpotlightLike = macroPlan.isSpotlightLikeTarget
        let macroDataSize = Int(PHTVEngineRuntimeFacade.engineDataMacroDataSize())

        #if DEBUG
        NSLog("[Macro] handleMacro: target='%@', isSpotlight=%d (postToHID=%d), backspaceCount=%d, macroSize=%d",
              effectiveTarget ?? "",
              isSpotlightLike ? 1 : 0,
              PHTVEventRuntimeContextService.postToHIDTapEnabled() ? 1 : 0,
              Int(PHTVEngineRuntimeFacade.engineDataBackspaceCount()),
              macroDataSize)
        #endif

        if macroPlan.shouldTryAXReplacement {
            let macroData = macroDataSnapshot(count: macroDataSize)
            let replacedByAX = PHTVEngineDataBridge.replaceSpotlightLikeMacroIfNeeded(
                isSpotlightLike ? 1 : 0,
                backspaceCount: Int32(PHTVEngineRuntimeFacade.engineDataBackspaceCount()),
                macroData: macroData,
                codeTable: Int32(PHTVEngineRuntimeFacade.currentCodeTable()),
                safeMode: PHTVEngineRuntimeFacade.safeModeEnabled())
            if replacedByAX {
                #if DEBUG
                NSLog("[Macro] Spotlight: AX API succeeded")
                #endif
                return
            }
            #if DEBUG
            NSLog("[Macro] Spotlight: AX API failed, falling back to synthetic events")
            #endif
        }

        if macroPlan.shouldApplyBrowserFix {
            PHTVKeyEventSenderService.sendEmptyCharacter()
            PHTVEngineRuntimeFacade.setEngineDataBackspaceCount(UInt8(macroPlan.adjustedBackspaceCount))
        }

        if PHTVEngineRuntimeFacade.engineDataBackspaceCount() > 0 {
            PHTVKeyEventSenderService.sendBackspaceSequenceWithDelay(
                Int32(PHTVEngineRuntimeFacade.engineDataBackspaceCount()))
        }

        if !macroPlan.useStepByStepSend {
            sendNewCharString(dataFromMacro: true, offset: 0, keycode: keycode, flags: flags)
        } else {
            let macroCount = Int32(PHTVEngineRuntimeFacade.engineDataMacroDataSize())
            let cliSpeedFactor = PHTVCliRuntimeStateService.currentSpeedFactor()
            let isCli = PHTVEventRuntimeContextService.isCliTargetEnabled()
            let scaledCliTextDelayUs: UInt64 = isCli
                ? UInt64(PHTVTimingService.scaleDelayUseconds(
                    PHTVTimingService.clampToUseconds(PHTVCliRuntimeStateService.cliTextDelayUs()),
                    factor: cliSpeedFactor))
                : 0
            let scaledCliPostSendBlockUs: UInt64 = isCli
                ? PHTVTimingService.scaleDelayMicroseconds(
                    PHTVCliRuntimeStateService.cliPostSendBlockUs(), factor: cliSpeedFactor)
                : 0
            let sendPlan = PHTVSendSequenceService.sequencePlan(
                forCliTarget: isCli,
                itemCount: macroCount,
                scaledCliTextDelayUs: Int64(scaledCliTextDelayUs),
                scaledCliPostSendBlockUs: Int64(scaledCliPostSendBlockUs))
            let interItemDelayUs = PHTVTimingService.clampToUseconds(
                UInt64(max(Int64(0), sendPlan.interItemDelayUs)))
            let pureCharMask = EngineBitMask.pureCharacter
            let totalMacroSize = Int(PHTVEngineRuntimeFacade.engineDataMacroDataSize())
            for i in 0..<totalMacroSize {
                let macroItem = PHTVEngineRuntimeFacade.engineDataMacroDataAt(Int32(i))
                if (macroItem & pureCharMask) != 0 {
                    PHTVKeyEventSenderService.sendPureCharacter(UInt16(macroItem & 0xFFFF))
                } else {
                    PHTVKeyEventSenderService.sendKeyCode(macroItem)
                }
                if interItemDelayUs > 0 && i + 1 < totalMacroSize {
                    usleep(interItemDelayUs)
                }
            }
            if sendPlan.shouldScheduleCliBlock {
                PHTVCliRuntimeStateService.scheduleBlock(
                    forMicroseconds: UInt64(max(Int64(0), sendPlan.cliBlockUs)),
                    nowMachTime: mach_absolute_time())
            }
        }

        if macroPlan.shouldSendTriggerKey {
            let hasCaps = (flags & CGEventFlags.maskShift.rawValue) != 0
            PHTVKeyEventSenderService.sendKeyCode(
                UInt32(keycode) | (hasCaps ? EngineBitMask.caps : 0))
        }
    }

    // MARK: - Private helpers

    private static func buildChar(_ tempChar: UInt32,
                                  codeTable: Int,
                                  pureCharMask: UInt32,
                                  charCodeMask: UInt32,
                                  into newCharString: inout [UInt16],
                                  outputIndex: inout Int,
                                  newCharSize: inout Int) {
        if (tempChar & pureCharMask) != 0 {
            newCharString[outputIndex] = UInt16(tempChar & 0xFFFF)
            outputIndex += 1
            if PHTVEngineRuntimeFacade.isDoubleCode(Int32(codeTable)) {
                PHTVKeyEventSenderService.insertKeyLength(1)
            }
        } else if (tempChar & charCodeMask) == 0 {
            if PHTVEngineRuntimeFacade.isDoubleCode(Int32(codeTable)) {
                PHTVKeyEventSenderService.insertKeyLength(1)
            }
            newCharString[outputIndex] = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(tempChar)
            outputIndex += 1
        } else {
            switch codeTable {
            case 0: // Unicode — 2-byte code
                newCharString[outputIndex] = UInt16(tempChar & 0xFFFF)
                outputIndex += 1
            case 1, 2, 4: // TCVN3, VNI Windows, CP1258 — 1-byte codes
                let newCharHi = UInt16(PHTVEngineRuntimeFacade.hiByte(tempChar))
                let newCharLo = UInt16(PHTVEngineRuntimeFacade.lowByte(tempChar))
                newCharString[outputIndex] = newCharLo
                outputIndex += 1
                if newCharHi > 32 {
                    if codeTable == 2 { PHTVKeyEventSenderService.insertKeyLength(2) }
                    newCharString[outputIndex] = newCharHi
                    outputIndex += 1
                    newCharSize += 1
                } else {
                    if codeTable == 2 { PHTVKeyEventSenderService.insertKeyLength(1) }
                }
            case 3: // Unicode Compound
                var newChar = UInt16(tempChar & 0xFFFF)
                let newCharHi = UInt16(newChar >> 13)
                newChar &= 0x1FFF
                PHTVKeyEventSenderService.insertKeyLength(newCharHi > 0 ? 2 : 1)
                newCharString[outputIndex] = newChar
                outputIndex += 1
                if newCharHi > 0 {
                    newCharSize += 1
                    newCharString[outputIndex] = PHTVEngineRuntimeFacade.unicodeCompoundMarkAt(
                        Int32(newCharHi) - 1)
                    outputIndex += 1
                }
            default:
                break
            }
        }
    }

    private static func macroDataSnapshot(count: Int) -> [UInt32] {
        guard count > 0 else { return [] }
        var snapshot: [UInt32] = []
        snapshot.reserveCapacity(count)
        for index in 0..<count {
            snapshot.append(PHTVEngineRuntimeFacade.engineDataMacroDataAt(Int32(index)))
        }
        return snapshot
    }
}
