//
//  PHTVCharacterOutputService.swift
//  PHTV
//
//  Character output logic: sendNewCharString and handleMacro.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import CoreGraphics
import AppKit
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
        // Capture engine output once; avoids re-locking the engine per character.
        let hookData = PHTVEngineRuntimeFacade.engineDataResultSnapshot()
        let macroData = dataFromMacro ? PHTVEngineRuntimeFacade.engineDataMacroSnapshot() : []

        let maxBuf = 20
        var outputIndex = 0
        var loopIndex = 0
        let sourceCharCount = dataFromMacro ? macroData.count : Int(hookData.newCharCount)
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

        if sourceCharCount > 0 {
            if dataFromMacro {
                loopIndex = Int(offset)
                while loopIndex < macroData.count {
                    if outputIndex >= 16 { willContinueSending = true; break }
                    buildChar(macroData[loopIndex], codeTable: codeTable,
                              pureCharMask: pureCharMask, charCodeMask: charCodeMask,
                              into: &newCharString, outputIndex: &outputIndex)
                    loopIndex += 1
                }
            } else {
                loopIndex = Int(hookData.newCharCount) - 1 - Int(offset)
                while loopIndex >= 0 {
                    if outputIndex >= 16 { willContinueSending = true; break }
                    buildChar(hookData.char(at: loopIndex), codeTable: codeTable,
                              pureCharMask: pureCharMask, charCodeMask: charCodeMask,
                              into: &newCharString, outputIndex: &outputIndex)
                    loopIndex -= 1
                }
            }
        }

        let engineCode = Int(hookData.code)
        let vRestoreCode = Int(EngineSignalCode.restore)
        let vRestoreNewCode = Int(EngineSignalCode.restoreAndStartNewSession)
        let capsMask = EngineBitMask.caps

        if !willContinueSending && (engineCode == vRestoreCode || engineCode == vRestoreNewCode) {
            if EngineMacroKeyMap.character(for: UInt32(keycode)) != 0 {
                let hasCaps = (flags & CGEventFlags.maskAlphaShift.rawValue) != 0
                           || (flags & CGEventFlags.maskShift.rawValue) != 0
                let withCaps = UInt32(keycode) | (hasCaps ? capsMask : 0)
                newCharString[outputIndex] = EngineMacroKeyMap.character(for: withCaps)
                outputIndex += 1
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
    class func handleMacro(keycode: UInt16, flags: UInt64) -> Bool {
        var effectiveTarget = PHTVEventRuntimeContextService.effectiveTargetBundleIdValue()
        if effectiveTarget == nil {
            effectiveTarget = PHTVAppContextService.focusedBundleId(
                forSafeMode: PHTVEngineRuntimeFacade.safeModeEnabled(),
                cacheDurationMs: kSpotlightCacheDurationMs)
            if effectiveTarget == nil {
                effectiveTarget = PHTVAppContextService.currentFrontmostBundleId()
            }
        }

        if PHTVEngineRuntimeFacade.engineDataMatchedMacroSnippetType() == EngineMacroSnippetType.systemTextReplacement,
           PHTVSystemTextReplacementService.shouldDeferToNativeTextReplacement(forBundleId: effectiveTarget) {
            PHTVEngineDataBridge.startNewSession()
            #if DEBUG
            NSLog("[Macro] Deferring macOS Text Replacement to native app handling for target='%@'",
                  effectiveTarget ?? "")
            #endif
            return true
        }

        let originalBackspaceCount = PHTVEngineRuntimeFacade.engineDataBackspaceCount()
        let macroPlan = PHTVInputStrategyService.macroPlan(
            forPostToHIDTap: PHTVEventRuntimeContextService.postToHIDTapEnabled(),
            appIsSpotlightLike: PHTVEventRuntimeContextService.appIsSpotlightLike(),
            browserFixEnabled: PHTVEngineRuntimeFacade.fixRecommendBrowser() != 0,
            originalBackspaceCount: originalBackspaceCount,
            cliTarget: PHTVEventRuntimeContextService.isCliTargetEnabled(),
            globalStepByStep: PHTVEngineRuntimeFacade.isSendKeyStepByStepEnabled(),
            appNeedsStepByStep: PHTVEventRuntimeContextService.appNeedsStepByStep(),
            appNeedsPrecomposedBatched: PHTVEventRuntimeContextService.appNeedsPrecomposedBatched())

        let isSpotlightLike = macroPlan.isSpotlightLikeTarget
        // Capture macro output once; avoids re-locking the engine per item.
        let macroData = PHTVEngineRuntimeFacade.engineDataMacroSnapshot()

        #if DEBUG
        NSLog("[Macro] handleMacro: target='%@', isSpotlight=%d (postToHID=%d), backspaceCount=%d, macroSize=%d",
              effectiveTarget ?? "",
              isSpotlightLike ? 1 : 0,
              PHTVEventRuntimeContextService.postToHIDTapEnabled() ? 1 : 0,
              Int(originalBackspaceCount),
              macroData.count)
        #endif

        if macroPlan.shouldTryAXReplacement {
            let replacedByAX = PHTVEngineDataBridge.replaceSpotlightLikeMacroIfNeeded(
                isSpotlightLike ? 1 : 0,
                backspaceCount: originalBackspaceCount,
                macroData: macroData,
                codeTable: Int32(PHTVEngineRuntimeFacade.currentCodeTable()),
                safeMode: PHTVEngineRuntimeFacade.safeModeEnabled())
            if replacedByAX {
                #if DEBUG
                NSLog("[Macro] Spotlight: AX API succeeded")
                #endif
                return false
            }
            #if DEBUG
            NSLog("[Macro] Spotlight: AX API failed, falling back to synthetic events")
            #endif
        }

        var effectiveBackspaceCount = originalBackspaceCount
        if macroPlan.shouldApplyBrowserFix {
            PHTVKeyEventSenderService.sendEmptyCharacter()
            PHTVEngineRuntimeFacade.setEngineDataBackspaceCount(UInt8(macroPlan.adjustedBackspaceCount))
            effectiveBackspaceCount = macroPlan.adjustedBackspaceCount
        }

        if effectiveBackspaceCount > 0 {
            PHTVKeyEventSenderService.sendBackspaceSequenceWithDelay(effectiveBackspaceCount)
        }

        if !macroPlan.useStepByStepSend {
            sendNewCharString(dataFromMacro: true, offset: 0, keycode: keycode, flags: flags)
        } else {
            let pureCharMask = EngineBitMask.pureCharacter
            PHTVSendSequenceService.sendItemsStepByStep(count: macroData.count) { index in
                let macroItem = macroData[index]
                if (macroItem & pureCharMask) != 0 {
                    PHTVKeyEventSenderService.sendPureCharacter(UInt16(macroItem & 0xFFFF))
                } else {
                    PHTVKeyEventSenderService.sendKeyCode(macroItem)
                }
            }
        }

        if macroPlan.shouldSendTriggerKey {
            let hasCaps = (flags & CGEventFlags.maskShift.rawValue) != 0
            PHTVKeyEventSenderService.sendKeyCode(
                UInt32(keycode) | (hasCaps ? EngineBitMask.caps : 0))
        }

        return false
    }

    // MARK: - Private helpers

    private static func buildChar(_ tempChar: UInt32,
                                  codeTable: Int,
                                  pureCharMask: UInt32,
                                  charCodeMask: UInt32,
                                  into newCharString: inout [UInt16],
                                  outputIndex: inout Int) {
        if (tempChar & pureCharMask) != 0 {
            newCharString[outputIndex] = UInt16(tempChar & 0xFFFF)
            outputIndex += 1
            if EngineInputClassification.isDoubleCodeTable(Int32(codeTable)) {
                PHTVKeyEventSenderService.insertKeyLength(1)
            }
        } else if (tempChar & charCodeMask) == 0 {
            if EngineInputClassification.isDoubleCodeTable(Int32(codeTable)) {
                PHTVKeyEventSenderService.insertKeyLength(1)
            }
            newCharString[outputIndex] = EngineMacroKeyMap.character(for: tempChar)
            outputIndex += 1
        } else {
            switch codeTable {
            case 0: // Unicode — 2-byte code
                newCharString[outputIndex] = UInt16(tempChar & 0xFFFF)
                outputIndex += 1
            case 1, 2, 4: // TCVN3, VNI Windows, CP1258 — 1-byte codes
                let newCharHi = UInt16(EnginePackedData.highByte(tempChar))
                let newCharLo = UInt16(EnginePackedData.lowByte(tempChar))
                newCharString[outputIndex] = newCharLo
                outputIndex += 1
                if newCharHi > 32 {
                    if codeTable == 2 { PHTVKeyEventSenderService.insertKeyLength(2) }
                    newCharString[outputIndex] = newCharHi
                    outputIndex += 1
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
                    newCharString[outputIndex] = EnginePackedData.unicodeCompoundMark(at: Int32(newCharHi) - 1)
                    outputIndex += 1
                }
            default:
                break
            }
        }
    }
}
