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
            ? Int(phtvEngineDataMacroDataSize())
            : Int(phtvEngineDataNewCharCount())
        var newCharString = [UInt16](repeating: 0, count: maxBuf)
        var willContinueSending = false
        var willSendControlKey = false

        let codeTable = Int(phtvRuntimeCurrentCodeTable())
        let isSpotlightTarget = PHTVEventRuntimeContextService.postToHIDTapEnabled()
                             || PHTVEventRuntimeContextService.appIsSpotlightLike()
        let isPrecomposedBatched = PHTVEventRuntimeContextService.appNeedsPrecomposedBatched()
        let forcePrecomposed = ((codeTable == 3) && isSpotlightTarget)
                            || ((codeTable == 0 || codeTable == 3) && isPrecomposedBatched)

        let pureCharMask = phtvEnginePureCharacterMask()
        let charCodeMask = phtvEngineCharCodeMask()

        if newCharSize > 0 {
            if dataFromMacro {
                loopIndex = Int(offset)
                while loopIndex < Int(phtvEngineDataMacroDataSize()) {
                    if outputIndex >= 16 { willContinueSending = true; break }
                    let tempChar = phtvEngineDataMacroDataAt(Int32(loopIndex))
                    buildChar(tempChar, codeTable: codeTable,
                              pureCharMask: pureCharMask, charCodeMask: charCodeMask,
                              into: &newCharString,
                              outputIndex: &outputIndex, newCharSize: &newCharSize)
                    loopIndex += 1
                }
            } else {
                loopIndex = Int(phtvEngineDataNewCharCount()) - 1 - Int(offset)
                while loopIndex >= 0 {
                    if outputIndex >= 16 { willContinueSending = true; break }
                    let tempChar = phtvEngineDataCharAt(Int32(loopIndex))
                    buildChar(tempChar, codeTable: codeTable,
                              pureCharMask: pureCharMask, charCodeMask: charCodeMask,
                              into: &newCharString,
                              outputIndex: &outputIndex, newCharSize: &newCharSize)
                    loopIndex -= 1
                }
            }
        }

        let engineCode = Int(phtvEngineDataCode())
        let vRestoreCode = Int(phtvEngineVRestoreCode())
        let vRestoreNewCode = Int(phtvEngineVRestoreAndStartNewSessionCode())
        let capsMask = phtvEngineCapsMask()

        if !willContinueSending && (engineCode == vRestoreCode || engineCode == vRestoreNewCode) {
            if phtvEngineMacroKeyCodeToCharacter(UInt32(keycode)) != 0 {
                let hasCaps = (flags & CGEventFlags.maskAlphaShift.rawValue) != 0
                           || (flags & CGEventFlags.maskShift.rawValue) != 0
                let withCaps = UInt32(keycode) | (hasCaps ? capsMask : 0)
                newCharString[outputIndex] = phtvEngineMacroKeyCodeToCharacter(withCaps)
                outputIndex += 1
                newCharSize += 1
            } else {
                willSendControlKey = true
            }
        }
        if !willContinueSending && engineCode == vRestoreNewCode {
            phtvRuntimeStartNewSession()
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
                    safeMode: phtvRuntimeSafeMode())
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
                forSafeMode: phtvRuntimeSafeMode(),
                cacheDurationMs: kSpotlightCacheDurationMs)
            if effectiveTarget == nil {
                effectiveTarget = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            }
        }

        let macroPlan = PHTVInputStrategyService.macroPlan(
            forPostToHIDTap: PHTVEventRuntimeContextService.postToHIDTapEnabled(),
            appIsSpotlightLike: PHTVEventRuntimeContextService.appIsSpotlightLike(),
            browserFixEnabled: phtvRuntimeFixRecommendBrowser() != 0,
            originalBackspaceCount: Int32(phtvEngineDataBackspaceCount()),
            cliTarget: PHTVEventRuntimeContextService.isCliTargetEnabled(),
            globalStepByStep: phtvRuntimeIsSendKeyStepByStepEnabled(),
            appNeedsStepByStep: PHTVEventRuntimeContextService.appNeedsStepByStep())

        let isSpotlightLike = macroPlan.isSpotlightLikeTarget

        #if DEBUG
        NSLog("[Macro] handleMacro: target='%@', isSpotlight=%d (postToHID=%d), backspaceCount=%d, macroSize=%d",
              effectiveTarget ?? "",
              isSpotlightLike ? 1 : 0,
              PHTVEventRuntimeContextService.postToHIDTapEnabled() ? 1 : 0,
              Int(phtvEngineDataBackspaceCount()),
              phtvEngineDataMacroDataSize())
        #endif

        if macroPlan.shouldTryAXReplacement {
            let replacedByAX = PHTVEngineDataBridge.replaceSpotlightLikeMacroIfNeeded(
                isSpotlightLike ? 1 : 0,
                backspaceCount: Int32(phtvEngineDataBackspaceCount()),
                macroData: phtvEngineDataMacroDataPtr(),
                count: Int32(phtvEngineDataMacroDataSize()),
                codeTable: Int32(phtvRuntimeCurrentCodeTable()),
                safeMode: phtvRuntimeSafeMode())
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
            phtvEngineDataSetBackspaceCount(UInt8(macroPlan.adjustedBackspaceCount))
        }

        if phtvEngineDataBackspaceCount() > 0 {
            PHTVKeyEventSenderService.sendBackspaceSequenceWithDelay(
                Int32(phtvEngineDataBackspaceCount()))
        }

        if !macroPlan.useStepByStepSend {
            sendNewCharString(dataFromMacro: true, offset: 0, keycode: keycode, flags: flags)
        } else {
            let macroCount = Int32(phtvEngineDataMacroDataSize())
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
            let pureCharMask = phtvEnginePureCharacterMask()
            let totalMacroSize = Int(phtvEngineDataMacroDataSize())
            for i in 0..<totalMacroSize {
                let macroItem = phtvEngineDataMacroDataAt(Int32(i))
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
                UInt32(keycode) | (hasCaps ? phtvEngineCapsMask() : 0))
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
            if phtvRuntimeIsDoubleCode(Int32(codeTable)) {
                PHTVKeyEventSenderService.insertKeyLength(1)
            }
        } else if (tempChar & charCodeMask) == 0 {
            if phtvRuntimeIsDoubleCode(Int32(codeTable)) {
                PHTVKeyEventSenderService.insertKeyLength(1)
            }
            newCharString[outputIndex] = phtvEngineMacroKeyCodeToCharacter(tempChar)
            outputIndex += 1
        } else {
            switch codeTable {
            case 0: // Unicode — 2-byte code
                newCharString[outputIndex] = UInt16(tempChar & 0xFFFF)
                outputIndex += 1
            case 1, 2, 4: // TCVN3, VNI Windows, CP1258 — 1-byte codes
                let newCharHi = UInt16(phtvEngineHiByte(tempChar))
                let newCharLo = UInt16(phtvEngineLowByte(tempChar))
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
                    newCharString[outputIndex] = phtvEngineUnicodeCompoundMarkAt(
                        Int32(newCharHi) - 1)
                    outputIndex += 1
                }
            default:
                break
            }
        }
    }
}
