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
        // Keep one immutable result for the entire send, including multi-chunk
        // macros and the restore trigger. Source offsets count engine items;
        // chunk capacity counts UTF-16 units.
        let hookData = PHTVEngineRuntimeFacade.engineDataResultSnapshot()
        let sourceItems = dataFromMacro ? PHTVEngineRuntimeFacade.engineDataMacroSnapshot() : hookData.chars
        let sourceCount = dataFromMacro ? sourceItems.count : max(0, min(Int(hookData.newCharCount), sourceItems.count))
        var sourceOffset = min(Int(offset), sourceCount)
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        let isSpotlightTarget = PHTVEventRuntimeContextService.postToHIDTapEnabled()
                             || PHTVEventRuntimeContextService.appIsSpotlightLike()
        let isPrecomposedBatched = PHTVEventRuntimeContextService.appNeedsPrecomposedBatched()
        let forcePrecomposed = ((codeTable == 3) && isSpotlightTarget)
                            || ((codeTable == 0 || codeTable == 3) && isPrecomposedBatched)
        var willSendControlKey = false

        repeat {
            let chunk = PHTVTextOutputEncoder.nextChunk(
                from: sourceItems,
                sourceCount: sourceCount,
                sourceOffset: sourceOffset,
                reversed: !dataFromMacro,
                codeTable: codeTable
            )
            sourceOffset = chunk.nextSourceOffset
            var finalChars = chunk.units
            for length in chunk.syncKeyLengths {
                PHTVKeyEventSenderService.insertKeyLength(length)
            }

            if sourceOffset == sourceCount {
                if hookData.code == EngineSignalCode.restore || hookData.code == EngineSignalCode.restoreAndStartNewSession {
                    if EngineMacroKeyMap.character(for: UInt32(keycode)) != 0 {
                        let hasCaps = (flags & CGEventFlags.maskAlphaShift.rawValue) != 0
                                   || (flags & CGEventFlags.maskShift.rawValue) != 0
                        let withCaps = UInt32(keycode) | (hasCaps ? EngineBitMask.caps : 0)
                        finalChars.append(EngineMacroKeyMap.character(for: withCaps))
                    } else {
                        willSendControlKey = true
                    }
                }
                if hookData.code == EngineSignalCode.restoreAndStartNewSession {
                    PHTVEngineDataBridge.startNewSession()
                }
            }

            if forcePrecomposed && !finalChars.isEmpty {
                finalChars = Array(String(decoding: finalChars, as: UTF16.self).precomposedStringWithCanonicalMapping.utf16)
            }
            finalChars.withUnsafeBufferPointer { chars in
                if isSpotlightTarget {
                    let backspaceCount = PHTVEventRuntimeContextService.takePendingBackspaceCount()
                    let axSucceeded = PHTVEventContextBridgeService.replaceFocusedTextViaAX(
                        backspaceCount: backspaceCount,
                        insertText: String(decoding: chars, as: UTF16.self),
                        verify: backspaceCount > 0,
                        safeMode: PHTVEngineRuntimeFacade.safeModeEnabled())
                    if !axSucceeded {
                        PHTVKeyEventSenderService.sendBackspaceSequenceWithDelay(backspaceCount)
                        if let ptr = chars.baseAddress, !chars.isEmpty {
                            PHTVKeyEventSenderService.sendUnicodeStringChunked(
                                ptr, len: Int32(chars.count),
                                chunkSize: Int32(chars.count), interDelayUs: 0)
                        }
                    }
                } else if let ptr = chars.baseAddress, !chars.isEmpty {
                    let isCli = PHTVEventRuntimeContextService.isCliTargetEnabled()
                    PHTVKeyEventSenderService.sendUnicodeStringChunked(
                        ptr, len: Int32(chars.count),
                        chunkSize: isCli ? max(1, PHTVCliRuntimeStateService.cliTextChunkSize()) : Int32(chars.count),
                        interDelayUs: isCli ? PHTVCliRuntimeStateService.cliTextDelayUs() : 0)
                }
            }
        } while sourceOffset < sourceCount

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

        if phtvRuntimeNativeSystemTextReplacementEnabled() != 0,
           PHTVEngineRuntimeFacade.engineDataMatchedMacroSnippetType() == EngineMacroSnippetType.systemTextReplacement,
           PHTVSystemTextReplacementService.shouldDeferToNativeTextReplacement(
               forBundleId: effectiveTarget,
               document: PHTVAccessibilityService.focusedWindowDocumentForFrontmostAppValue(),
               windowTitle: PHTVAccessibilityService.focusedWindowTitleForFrontmostAppValue()) {
            PHTVEngineDataBridge.startNewSession()
            #if DEBUG
            NSLog("[Macro] Deferring macOS Text Replacement to native app handling for target='%@'",
                  effectiveTarget ?? "")
            #endif
            return true
        }

        let originalBackspaceCount = PHTVEngineRuntimeFacade.engineDataBackspaceCount()
        let safeModeEnabled = PHTVEngineRuntimeFacade.safeModeEnabled()
        let isZaloContext = PHTVEventContextBridgeService.isZaloContext(
            forBundleId: effectiveTarget,
            safeMode: safeModeEnabled)
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
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        let shouldUseReliableWholeTextInsertion =
            PHTVInputStrategyService.shouldUseReliableWholeTextInsertion(
                forZaloContext: isZaloContext,
                macroItemCount: Int32(macroData.count),
                codeTable: codeTable)

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
                codeTable: codeTable,
                safeMode: safeModeEnabled)
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

        var insertedAsWholeText = false
        if shouldUseReliableWholeTextInsertion {
            let macroText = PHTVEngineDataBridge.macroString(
                fromMacroData: macroData,
                codeTable: codeTable)
            insertedAsWholeText = PHTVTransientTextInsertionService.insert(macroText)
            #if DEBUG
            NSLog("[Macro] Zalo reliable whole-text insertion: %@", insertedAsWholeText ? "success" : "fallback")
            #endif
        }

        if insertedAsWholeText {
            // Nothing else to send: the paste shortcut inserted the complete
            // expansion as one editor transaction.
        } else if !macroPlan.useStepByStepSend {
            sendNewCharString(dataFromMacro: true, offset: 0, keycode: keycode, flags: flags)
        } else {
            let pureCharMask = EngineBitMask.pureCharacter
            PHTVSendSequenceService.sendItemsStepByStep(count: macroData.count) { index in
                let macroItem = macroData[index]
                if (macroItem & pureCharMask) != 0 {
                    PHTVKeyEventSenderService.sendPureScalar(macroItem & ~pureCharMask)
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

}
