//
//  PHTVEventCallbackService.swift
//  PHTV
//
//  Main event tap callback logic.
//  Migrated from PHTV.mm (PHTVCallback, ConvertEventToKeyboardLayoutCompatKeyCode).
//

import ApplicationServices
import Darwin
import Foundation

final class PHTVEventCallbackService {

    // MARK: - Constants

    private static let kSpotlightCacheDurationMs: UInt64 = 150
    private static let kAppSwitchCacheDurationMs: UInt64 = 100
    private static let kTextReplacementDeleteWindowMs: UInt64 = 30000
    private static let kAppCharacteristicsCacheMaxAgeMs: UInt64 = 10000
    #if DEBUG
    private static let kDebugLogThrottleMs: UInt64 = 500
    #endif

    // MARK: - Public entry point

    static func handle(proxy: CGEventTapProxy,
                       type: CGEventType,
                       event: CGEvent,
                       refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        autoreleasepool {
            handleInner(proxy: proxy, type: type, event: event, refcon: refcon)
        }
    }

    // MARK: - Main dispatch

    private static func handleInner(proxy: CGEventTapProxy,
                                    type: CGEventType,
                                    event: CGEvent,
                                    refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        // CRITICAL: If permission was lost, reject ALL events immediately
        if PHTVEventTapService.hasPermissionLost() {
            return Unmanaged.passRetained(event)
        }

        // CLI stabilization: block briefly after synthetic injection to avoid interleaving
        if type == .keyDown {
            let remainUs = PHTVCliRuntimeStateService.remainingBlockMicroseconds(
                forNowMachTime: mach_absolute_time())
            if remainUs > 0 {
                usleep(PHTVTimingService.clampToUseconds(remainUs))
            }
        }

        // Auto-recover when macOS temporarily disables the event tap
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            PHTVEventTapService.handleEventTapDisabled(type)
            return Unmanaged.passRetained(event)
        }

        // Perform periodic health check and recovery.
        let tapHealthOk = PHTVEventTapHealthService.checkAndRecover(forEventType: type)
        _ = tapHealthOk

        // Skip events injected by PHTV itself (marker-based)
        if event.getIntegerValueField(.eventSourceUserData) == PHTVEngineRuntimeFacade.eventMarkerValue() {
            return Unmanaged.passRetained(event)
        }

        PHTVEventRuntimeContextService.clearCliPostFlags()
        let eventFlags = event.flags
        var eventKeycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // Track text-replacement keydown patterns (external DELETE and following SPACE).
        if type == .keyDown {
            PHTVTextReplacementDecisionService.handleKeyDownTextReplacementTracking(
                forKeyCode: Int32(eventKeycode),
                deleteKeyCode: Int32(PHTVEngineRuntimeFacade.keyDeleteCode()),
                spaceKeyCode: Int32(PHTVEngineRuntimeFacade.spaceKeyCode()),
                sourceStateID: event.getIntegerValueField(.eventSourceStateID))
        }

        // Handle Spotlight detection optimization.
        PHTVEventContextBridgeService.handleSpotlightCacheInvalidation(
            forType: type,
            keycode: eventKeycode,
            flags: eventFlags)

        // If pause key is being held, strip pause modifier from events to prevent special characters
        // BUT only if no other modifiers are pressed (to preserve system shortcuts like Option+Cmd+V)
        if PHTVModifierRuntimeStateService.pausePressedValue() &&
           (type == .keyDown || type == .keyUp) {
            let pauseKey = Int32(PHTVEngineRuntimeFacade.pauseKey())
            if PHTVHotkeyService.shouldStripPauseModifier(
                withFlags: eventFlags.rawValue,
                pauseKeyCode: pauseKey) {
                let newFlagsRaw = PHTVHotkeyService.stripPauseModifier(
                    forFlags: eventFlags.rawValue,
                    pauseKeyCode: pauseKey)
                event.flags = CGEventFlags(rawValue: newFlagsRaw)
            }
        }

        if type == .keyDown && PHTVEngineRuntimeFacade.performLayoutCompat() != 0 {
            eventKeycode = PHTVHotkeyService.convertEventToKeyboardLayoutCompatKeyCode(
                event, fallback: eventKeycode)
        }

        // Switch-language / quick-convert / emoji hotkey handling
        if type == .keyDown {
            let quickConvertHotkey = PHTVConvertToolHotkeyService.currentHotkey()
            let hotkeyAction = PHTVEventContextBridgeService.processKeyDownHotkeyAndApplyState(
                forKeyCode: eventKeycode,
                currentFlags: eventFlags.rawValue,
                switchHotkey: Int32(PHTVEngineRuntimeFacade.switchKeyStatus()),
                convertHotkey: quickConvertHotkey,
                emojiEnabled: Int32(PHTVEngineRuntimeFacade.enableEmojiHotkey()),
                emojiModifiers: Int32(PHTVEngineRuntimeFacade.emojiHotkeyModifiers()),
                emojiHotkeyKeyCode: Int32(PHTVEngineRuntimeFacade.emojiHotkeyKeyCode()))
            if hotkeyAction != PHTVKeyDownHotkeyAction.none.rawValue {
                if MainActor.assumeIsolated({ PHTVRuntimeUIBridgeService.handleKeyDownHotkeyAction(Int32(hotkeyAction)) }) {
                    PHTVModifierRuntimeStateService.setLastFlagsValue(0)
                    PHTVModifierRuntimeStateService.setHasJustUsedHotKeyValue(true)
                    return nil
                }
            }
        }

        if type == .keyDown {
            if PHTVEngineRuntimeFacade.upperCaseFirstChar() != 0 &&
               PHTVEngineRuntimeFacade.upperCaseExcludedForCurrentApp() == 0 {
                let keyWithCaps = UInt32(eventKeycode) |
                    ((eventFlags.contains(.maskShift) || eventFlags.contains(.maskAlphaShift))
                     ? PHTVEngineRuntimeFacade.capsMask() : 0)
                let keyCharacter = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(keyWithCaps)
                let isNavigationKey = PHTVEngineRuntimeFacade.isNavigationKey(eventKeycode)
                let shouldPrime = PHTVEventContextBridgeService.shouldPrimeUppercaseOnKeyDown(
                    withFlags: eventFlags.rawValue,
                    keyCode: eventKeycode,
                    keyCharacter: keyCharacter,
                    isNavigationKey: isNavigationKey,
                    safeMode: PHTVEngineRuntimeFacade.safeModeEnabled(),
                    uppercaseEnabled: Int32(PHTVEngineRuntimeFacade.upperCaseFirstChar()),
                    uppercaseExcluded: Int32(PHTVEngineRuntimeFacade.upperCaseExcludedForCurrentApp()))
                if shouldPrime {
                    PHTVEngineRuntimeFacade.primeUpperCaseFirstChar()
                }
            }

            PHTVEventContextBridgeService.applyKeyDownModifierTracking(
                forFlags: eventFlags.rawValue,
                restoreOnEscape: Int32(PHTVEngineRuntimeFacade.restoreOnEscape()),
                customEscapeKey: Int32(PHTVEngineRuntimeFacade.customEscapeKey()),
                switchHotkey: Int32(PHTVEngineRuntimeFacade.switchKeyStatus()),
                convertHotkey: PHTVConvertToolHotkeyService.currentHotkey(),
                emojiEnabled: Int32(PHTVEngineRuntimeFacade.enableEmojiHotkey()),
                emojiModifiers: Int32(PHTVEngineRuntimeFacade.emojiHotkeyModifiers()),
                emojiHotkeyKeyCode: Int32(PHTVEngineRuntimeFacade.emojiHotkeyKeyCode()))

        } else if type == .flagsChanged {
            let lastFlags = PHTVModifierRuntimeStateService.lastFlagsValue()
            if lastFlags == 0 || lastFlags < eventFlags.rawValue {
                let pressResult = PHTVEventContextBridgeService.handleModifierPress(
                    withFlags: eventFlags.rawValue,
                    restoreOnEscape: Int32(PHTVEngineRuntimeFacade.restoreOnEscape()),
                    customEscapeKey: Int32(PHTVEngineRuntimeFacade.customEscapeKey()),
                    pauseKeyEnabled: Int32(PHTVEngineRuntimeFacade.pauseKeyEnabled()),
                    pauseKeyCode: Int32(PHTVEngineRuntimeFacade.pauseKey()),
                    currentLanguage: Int32(PHTVEngineRuntimeFacade.currentLanguage()))
                if pressResult.shouldUpdateLanguage {
                    PHTVEngineRuntimeFacade.setCurrentLanguage(pressResult.language)
                }
            } else if lastFlags > eventFlags.rawValue {
                let releaseResult = PHTVEventContextBridgeService.handleModifierRelease(
                    oldFlags: lastFlags,
                    newFlags: eventFlags.rawValue,
                    restoreOnEscape: Int32(PHTVEngineRuntimeFacade.restoreOnEscape()),
                    customEscapeKey: Int32(PHTVEngineRuntimeFacade.customEscapeKey()),
                    switchHotkey: Int32(PHTVEngineRuntimeFacade.switchKeyStatus()),
                    convertHotkey: PHTVConvertToolHotkeyService.currentHotkey(),
                    emojiEnabled: Int32(PHTVEngineRuntimeFacade.enableEmojiHotkey()),
                    emojiModifiers: Int32(PHTVEngineRuntimeFacade.emojiHotkeyModifiers()),
                    emojiKeyCode: Int32(PHTVEngineRuntimeFacade.emojiHotkeyKeyCode()),
                    tempOffSpellingEnabled: Int32(PHTVEngineRuntimeFacade.tempOffSpelling()),
                    tempOffEngineEnabled: Int32(PHTVEngineRuntimeFacade.tempOffEngine()),
                    pauseKeyEnabled: Int32(PHTVEngineRuntimeFacade.pauseKeyEnabled()),
                    pauseKeyCode: Int32(PHTVEngineRuntimeFacade.pauseKey()),
                    currentLanguage: Int32(PHTVEngineRuntimeFacade.currentLanguage()))

                let shouldAttemptRestore = releaseResult.shouldAttemptRestore
                let releaseAction = Int(releaseResult.releaseAction)

                // Releasing modifiers - check for restore modifier key first
                if shouldAttemptRestore {
                    // Restore modifier released without any other key press - trigger restore
                    if PHTVEngineRuntimeFacade.restoreToRawKeys() {
                        // Successfully restored - pData now contains restore info
                        // Send backspaces to delete Vietnamese characters
                        let bsCount = Int(PHTVEngineRuntimeFacade.engineDataBackspaceCount())
                        if bsCount > 0 && bsCount < Int(PHTVEngineRuntimeFacade.engineMaxBuffer()) {
                            PHTVKeyEventSenderService.sendBackspaceSequenceWithDelay(Int32(bsCount))
                        }
                        // Send the raw ASCII characters
                        PHTVCharacterOutputService.sendNewCharString(
                            dataFromMacro: false, offset: 0,
                            keycode: eventKeycode, flags: eventFlags.rawValue)
                        return nil
                    }
                }

                if releaseResult.shouldUpdateLanguage {
                    PHTVEngineRuntimeFacade.setCurrentLanguage(releaseResult.language)
                }

                if MainActor.assumeIsolated({ PHTVRuntimeUIBridgeService.handleModifierReleaseHotkeyAction(Int32(releaseAction)) }) {
                    PHTVModifierRuntimeStateService.setHasJustUsedHotKeyValue(true)
                    return nil
                }

                if releaseAction == PHTVModifierReleaseAction.tempOffSpelling.rawValue {
                    PHTVEngineRuntimeFacade.tempOffSpellChecking()
                } else if releaseAction == PHTVModifierReleaseAction.tempOffEngine.rawValue {
                    PHTVEngineRuntimeFacade.tempOffEngineNow()
                }

                PHTVModifierRuntimeStateService.setHasJustUsedHotKeyValue(false)
            }
        }

        // Also check correct event hooked
        guard type == .keyDown || type == .keyUp ||
              type == .leftMouseDown || type == .rightMouseDown else {
            return Unmanaged.passRetained(event)
        }

        PHTVEventRuntimeContextService.setEventTapProxyRawValue(
            UInt64(UInt(bitPattern: UnsafeRawPointer(proxy))))

        // Skip Vietnamese processing for Spotlight and similar launcher apps
        if PHTVEventContextBridgeService.shouldDisableVietnamese(
            forEvent: event,
            safeMode: PHTVEngineRuntimeFacade.safeModeEnabled(),
            cacheDurationMs: kAppSwitchCacheDurationMs,
            spotlightCacheDurationMs: kSpotlightCacheDurationMs) {
            return Unmanaged.passRetained(event)
        }

        // If is in English mode
        let currentLanguage = PHTVEngineRuntimeFacade.currentLanguage()
        if currentLanguage == 0 {
            if PHTVEngineRuntimeFacade.useMacro() != 0 && PHTVEngineRuntimeFacade.useMacroInEnglishMode() != 0 &&
               type == .keyDown {
                PHTVEngineRuntimeFacade.handleEnglishModeKeyDown(
                    keyCode: eventKeycode,
                    isCaps: eventFlags.contains(.maskShift) || eventFlags.contains(.maskAlphaShift),
                    hasOtherControlKey: PHTVEventContextBridgeService.hasOtherControlKey(
                        withFlags: eventFlags.rawValue)
                )

                if Int(PHTVEngineRuntimeFacade.engineDataCode()) == PHTVEngineRuntimeFacade.engineReplaceMacroCode() {
                    _ = PHTVEventContextBridgeService.prepareTargetContextAndConfigureRuntime(
                        forEvent: event,
                        safeMode: PHTVEngineRuntimeFacade.safeModeEnabled(),
                        spotlightCacheDurationMs: kSpotlightCacheDurationMs,
                        appCharacteristicsMaxAgeMs: kAppCharacteristicsCacheMaxAgeMs)
                    PHTVCharacterOutputService.handleMacro(
                        keycode: eventKeycode, flags: eventFlags.rawValue)
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }

        // Handle mouse - reset session to avoid stale typing state
        if type == .leftMouseDown || type == .rightMouseDown {
            PHTVEngineSessionService.requestNewSessionInternal(allowUppercasePrime: true)
            return Unmanaged.passRetained(event)
        }

        // If "turn off Vietnamese when in other language" mode on
        if PHTVEngineRuntimeFacade.otherLanguageMode() != 0 {
            if !PHTVInputSourceLanguageService.shouldAllowVietnameseForOtherLanguageMode() {
                return Unmanaged.passRetained(event)
            }
        }

        // Handle keyboard
        if type == .keyDown {
            return handleKeyDown(proxy: proxy,
                                 event: event,
                                 eventKeycode: eventKeycode,
                                 eventFlags: eventFlags)
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - KeyDown processing

    private static func handleKeyDown(proxy: CGEventTapProxy,
                                      event: CGEvent,
                                      eventKeycode: CGKeyCode,
                                      eventFlags: CGEventFlags) -> Unmanaged<CGEvent>? {
        let targetContext = PHTVEventContextBridgeService.prepareTargetContextAndConfigureRuntime(
            forEvent: event,
            safeMode: PHTVEngineRuntimeFacade.safeModeEnabled(),
            spotlightCacheDurationMs: kSpotlightCacheDurationMs,
            appCharacteristicsMaxAgeMs: kAppCharacteristicsCacheMaxAgeMs)
        let spotlightActive = targetContext.spotlightActive
        let effectiveBundleId = targetContext.effectiveBundleId
        let appChars = targetContext.appCharacteristics

        #if DEBUG
        let eventTargetPID = Int32(event.getIntegerValueField(.eventTargetUnixProcessID))
        let eventTargetBundleId = targetContext.eventTargetBundleId
        let focusedBundleId = targetContext.focusedBundleId
        if PHTVEventRuntimeContextService.postToHIDTapEnabled() || spotlightActive {
            let currentCodeTable = PHTVEngineRuntimeFacade.currentCodeTable()
            PHTVSpotlightDetectionService.emitRuntimeDebugLog(
                "spotlightActive=\(spotlightActive ? 1 : 0) targetPID=\(eventTargetPID) eventTarget=\(eventTargetBundleId ?? "") focused=\(focusedBundleId ?? "") effective=\(effectiveBundleId ?? "") codeTable=\(currentCodeTable) keycode=\(eventKeycode)",
                throttleMs: kDebugLogThrottleMs)
        }
        #endif

        // Code table override guard — restored via defer when this function exits
        var savedCodeTable: Int32 = 0
        var codeTableOverrideActive = false
        defer {
            if codeTableOverrideActive {
                PHTVEngineRuntimeFacade.setCurrentCodeTable(savedCodeTable)
            }
        }

        let currentCodeTable = Int32(PHTVEngineRuntimeFacade.currentCodeTable())
        if PHTVInputStrategyService.shouldTemporarilyUseUnicodeCodeTable(
            forCurrentCodeTable: currentCodeTable,
            spotlightActive: spotlightActive,
            spotlightLikeApp: appChars.isSpotlightLike) {
            codeTableOverrideActive = true
            savedCodeTable = currentCodeTable
            PHTVEngineRuntimeFacade.setCurrentCodeTable(Int32(0))
        }

        // Send event signal to Engine
        let capsStatus: UInt8 = eventFlags.contains(.maskShift) ? 1
            : (eventFlags.contains(.maskAlphaShift) ? 2 : 0)
        PHTVEngineRuntimeFacade.handleKeyboardKeyDown(
            keyCode: eventKeycode,
            capsStatus: capsStatus,
            hasOtherControlKey: PHTVEventContextBridgeService.hasOtherControlKey(
                withFlags: eventFlags.rawValue)
        )

        #if DEBUG
        if eventKeycode == CGKeyCode(PHTVEngineRuntimeFacade.spaceKeyCode()) {
            NSLog("[TextReplacement] Engine result for SPACE: code=%d, extCode=%d, backspace=%d, newChar=%d",
                  PHTVEngineRuntimeFacade.engineDataCode(), PHTVEngineRuntimeFacade.engineDataExtCode(),
                  PHTVEngineRuntimeFacade.engineDataBackspaceCount(), PHTVEngineRuntimeFacade.engineDataNewCharCount())
        }
        if PHTVEngineRuntimeFacade.engineDataExtCode() == 5 {
            if Int(PHTVEngineRuntimeFacade.engineDataCode()) == PHTVEngineRuntimeFacade.engineRestoreCode() ||
               Int(PHTVEngineRuntimeFacade.engineDataCode()) == PHTVEngineRuntimeFacade.engineRestoreAndStartNewSessionCode() {
                NSLog("[AutoEnglish] ✓ RESTORE TRIGGERED: code=%d, backspace=%d, newChar=%d, keycode=%d (0x%X)",
                      PHTVEngineRuntimeFacade.engineDataCode(), PHTVEngineRuntimeFacade.engineDataBackspaceCount(),
                      PHTVEngineRuntimeFacade.engineDataNewCharCount(), eventKeycode, eventKeycode)
            } else {
                NSLog("[AutoEnglish] ⚠️ WARNING: extCode=5 but code=%d (not restore!)", PHTVEngineRuntimeFacade.engineDataCode())
            }
        } else if eventKeycode == CGKeyCode(PHTVEngineRuntimeFacade.spaceKeyCode()) &&
                  Int(PHTVEngineRuntimeFacade.engineDataCode()) == PHTVEngineRuntimeFacade.engineDoNothingCode() {
            NSLog("[AutoEnglish] ✗ NO RESTORE on SPACE: code=%d, extCode=%d",
                  PHTVEngineRuntimeFacade.engineDataCode(), PHTVEngineRuntimeFacade.engineDataExtCode())
        }
        #endif

        let signalAction = Int(PHTVInputStrategyService.engineSignalAction(
            forEngineCode: Int32(PHTVEngineRuntimeFacade.engineDataCode()),
            doNothingCode: Int32(PHTVEngineRuntimeFacade.engineDoNothingCode()),
            willProcessCode: Int32(PHTVEngineRuntimeFacade.engineWillProcessCode()),
            restoreCode: Int32(PHTVEngineRuntimeFacade.engineRestoreCode()),
            restoreAndStartNewSessionCode: Int32(PHTVEngineRuntimeFacade.engineRestoreAndStartNewSessionCode()),
            replaceMacroCode: Int32(PHTVEngineRuntimeFacade.engineReplaceMacroCode())))

        if signalAction == PHTVEngineSignalAction.doNothing.rawValue {
            // Navigation keys: trigger session restore to support keyboard-based edit-in-place
            if PHTVEngineRuntimeFacade.isNavigationKey(eventKeycode) {
                // TryToRestoreSessionFromAX -- commented out
            }

            let currTable = PHTVEngineRuntimeFacade.currentCodeTable()
            let shouldSendExtraBackspace =
                PHTVEventContextBridgeService.applyDoNothingSyncStateTransition(
                    forCodeTable: currTable,
                    extCode: Int32(PHTVEngineRuntimeFacade.engineDataExtCode()),
                    containsUnicodeCompound: appChars.containsUnicodeCompound)
            if shouldSendExtraBackspace {
                PHTVKeyEventSenderService.sendPhysicalBackspace()
            }
            return Unmanaged.passRetained(event)

        } else if signalAction == PHTVEngineSignalAction.processSignal.rawValue {
            let isBrowserApp = targetContext.isBrowser
            let isSpotlightTarget = targetContext.postToHIDTap
            let processSignalPlan = PHTVInputStrategyService.processSignalPlan(
                forBundleId: effectiveBundleId,
                keyCode: Int32(eventKeycode),
                spaceKeyCode: Int32(PHTVEngineRuntimeFacade.spaceKeyCode()),
                slashKeyCode: Int32(PHTVEngineRuntimeFacade.keySlashCode()),
                extCode: Int32(PHTVEngineRuntimeFacade.engineDataExtCode()),
                backspaceCount: Int32(PHTVEngineRuntimeFacade.engineDataBackspaceCount()),
                newCharCount: Int32(PHTVEngineRuntimeFacade.engineDataNewCharCount()),
                isBrowserApp: isBrowserApp,
                isSpotlightTarget: isSpotlightTarget,
                needsPrecomposedBatched: appChars.needsPrecomposedBatched,
                browserFixEnabled: PHTVEngineRuntimeFacade.fixRecommendBrowser() != 0)

            // FIGMA FIX: Force pass-through for Space key to support "Hand tool" (Hold Space)
            if processSignalPlan.shouldBypassForFigma {
                return Unmanaged.passRetained(event)
            }

            #if DEBUG
            if Int(PHTVEngineRuntimeFacade.engineDataCode()) == PHTVEngineRuntimeFacade.engineRestoreAndStartNewSessionCode() {
                fputs("[AutoEnglish] vRestoreAndStartNewSession START: backspace=\(PHTVEngineRuntimeFacade.engineDataBackspaceCount()), newChar=\(PHTVEngineRuntimeFacade.engineDataNewCharCount()), keycode=\(eventKeycode)\n", stderr)
            }
            #endif

            #if DEBUG
            let isSpotlightTargetDbg = processSignalPlan.isSpecialApp
            let isBrowserFix = processSignalPlan.isBrowserFix
            NSLog("[BrowserFix] Status: vFix=%d, app=%@, isBrowser=%d => isFix=%d | bs=%d, ext=%d",
                  PHTVEngineRuntimeFacade.fixRecommendBrowser(), effectiveBundleId ?? "",
                  isBrowserApp ? 1 : 0, isBrowserFix ? 1 : 0,
                  PHTVEngineRuntimeFacade.engineDataBackspaceCount(), PHTVEngineRuntimeFacade.engineDataExtCode())
            if isBrowserFix && PHTVEngineRuntimeFacade.engineDataBackspaceCount() > 0 {
                NSLog("[BrowserFix] Checking logic: fix=%d, ext=%d, special=%d, skipSp=%d, shortcut=%d, bs=%d",
                      isBrowserFix ? 1 : 0, PHTVEngineRuntimeFacade.engineDataExtCode(),
                      isSpotlightTargetDbg ? 1 : 0,
                      processSignalPlan.shouldSkipSpace ? 1 : 0,
                      processSignalPlan.isPotentialShortcut ? 1 : 0,
                      PHTVEngineRuntimeFacade.engineDataBackspaceCount())
            }
            #endif

            var isAddrBar = false
            if processSignalPlan.shouldTryBrowserAddressBarFix {
                isAddrBar = PHTVEventContextBridgeService.isFocusedElementAddressBar(
                    forSafeMode: PHTVEngineRuntimeFacade.safeModeEnabled())
                #if DEBUG
                NSLog("[BrowserFix] isFocusedElementAddressBar returned: %d", isAddrBar ? 1 : 0)
                #endif
            }

            var isNotionCodeBlockDetected = false
            if processSignalPlan.shouldTryLegacyNonBrowserFix {
                isNotionCodeBlockDetected = processSignalPlan.isNotionApp &&
                    PHTVEventContextBridgeService.isNotionCodeBlock(
                        forSafeMode: PHTVEngineRuntimeFacade.safeModeEnabled())
                #if DEBUG
                if isNotionCodeBlockDetected {
                    NSLog("[Notion] Code Block detected - using Standard Backspace")
                }
                #endif
            }

            let resolvedBackspacePlan = PHTVInputStrategyService.resolvedBackspacePlan(
                forBrowserAddressBarFix: processSignalPlan.shouldTryBrowserAddressBarFix,
                addressBarDetected: isAddrBar,
                legacyNonBrowserFix: processSignalPlan.shouldTryLegacyNonBrowserFix,
                containsUnicodeCompound: appChars.containsUnicodeCompound,
                notionCodeBlockDetected: isNotionCodeBlockDetected,
                backspaceCount: Int32(PHTVEngineRuntimeFacade.engineDataBackspaceCount()),
                maxBuffer: Int32(PHTVEngineRuntimeFacade.engineMaxBuffer()),
                safetyLimit: 15)

            let adjustmentAction = Int(resolvedBackspacePlan.adjustmentAction)
            if adjustmentAction == PHTVBackspaceAdjustmentAction.sendShiftLeftThenBackspace.rawValue {
                PHTVKeyEventSenderService.sendShiftAndLeftArrow()
                PHTVKeyEventSenderService.sendPhysicalBackspace()
            } else if adjustmentAction == PHTVBackspaceAdjustmentAction.sendEmptyCharacter.rawValue {
                #if DEBUG
                if isAddrBar {
                    NSLog("[PHTV Browser] Address Bar Detected (AX) -> Using SendEmptyCharacter (Fix Doubling)")
                }
                #endif
                PHTVKeyEventSenderService.sendEmptyCharacter()
            }

            let adjustedBackspaceCount = Int(resolvedBackspacePlan.sanitizedBackspaceCount)
            PHTVEngineRuntimeFacade.setEngineDataBackspaceCount(UInt8(adjustedBackspaceCount))

            #if DEBUG
            if resolvedBackspacePlan.isSafetyClampApplied {
                NSLog("[PHTV Safety] Blocked excessive backspaceCount: %d -> 15 (Key=%d)",
                      Int(resolvedBackspacePlan.adjustedBackspaceCount), eventKeycode)
            }
            if processSignalPlan.shouldLogSpaceSkip {
                NSLog("[TextReplacement] SKIPPED SendEmptyCharacter for SPACE to avoid Text Replacement conflict")
            }
            #endif

            // TEXT REPLACEMENT FIX
            let externalDeleteCount = PHTVEventContextBridgeService.externalDeleteCountValue()
            let shouldEvaluateTextReplacement =
                PHTVTextReplacementDecisionService.shouldEvaluate(
                    forKeyCode: Int32(eventKeycode),
                    spaceKeyCode: Int32(PHTVEngineRuntimeFacade.spaceKeyCode()),
                    backspaceCount: Int32(PHTVEngineRuntimeFacade.engineDataBackspaceCount()),
                    newCharCount: Int32(PHTVEngineRuntimeFacade.engineDataNewCharCount()))

            #if DEBUG
            if shouldEvaluateTextReplacement {
                NSLog("[PHTV TextReplacement] Key=%d: code=%d, extCode=%d, backspace=%d, newChar=%d, deleteCount=%d",
                      eventKeycode, PHTVEngineRuntimeFacade.engineDataCode(), PHTVEngineRuntimeFacade.engineDataExtCode(),
                      PHTVEngineRuntimeFacade.engineDataBackspaceCount(), PHTVEngineRuntimeFacade.engineDataNewCharCount(),
                      externalDeleteCount)
            }
            #endif

            if shouldEvaluateTextReplacement {
                let textReplacementDecision = PHTVTextReplacementDecisionService.evaluate(
                    forSpaceKey: true,
                    code: Int32(PHTVEngineRuntimeFacade.engineDataCode()),
                    extCode: Int32(PHTVEngineRuntimeFacade.engineDataExtCode()),
                    backspaceCount: Int32(PHTVEngineRuntimeFacade.engineDataBackspaceCount()),
                    newCharCount: Int32(PHTVEngineRuntimeFacade.engineDataNewCharCount()),
                    externalDeleteCount: externalDeleteCount,
                    restoreAndStartNewSessionCode: Int32(PHTVEngineRuntimeFacade.engineRestoreAndStartNewSessionCode()),
                    willProcessCode: Int32(PHTVEngineRuntimeFacade.engineWillProcessCode()),
                    restoreCode: Int32(PHTVEngineRuntimeFacade.engineRestoreCode()),
                    deleteWindowMs: kTextReplacementDeleteWindowMs)

                if textReplacementDecision.shouldBypassEvent {
                    #if DEBUG
                    if textReplacementDecision.isExternalDelete {
                        NSLog("[TextReplacement] Text replacement detected - passing through event (code=%d, backspace=%d, newChar=%d, deleteCount=%d, elapsedMs=%llu)",
                              PHTVEngineRuntimeFacade.engineDataCode(), PHTVEngineRuntimeFacade.engineDataBackspaceCount(),
                              PHTVEngineRuntimeFacade.engineDataNewCharCount(), externalDeleteCount,
                              textReplacementDecision.matchedElapsedMs)
                    } else if textReplacementDecision.isPatternMatch {
                        NSLog("[PHTV TextReplacement] Pattern %@ matched: code=%d, backspace=%d, newChar=%d, keycode=%d",
                              textReplacementDecision.patternLabel ?? "?",
                              PHTVEngineRuntimeFacade.engineDataCode(), PHTVEngineRuntimeFacade.engineDataBackspaceCount(),
                              PHTVEngineRuntimeFacade.engineDataNewCharCount(), eventKeycode)
                        NSLog("[PHTV TextReplacement] ✅ DETECTED - Skipping processing (code=%d, backspace=%d, newChar=%d)",
                              PHTVEngineRuntimeFacade.engineDataCode(), PHTVEngineRuntimeFacade.engineDataBackspaceCount(),
                              PHTVEngineRuntimeFacade.engineDataNewCharCount())
                    }
                    #endif
                    // CRITICAL: Return event to let macOS insert Space
                    return Unmanaged.passRetained(event)
                }

                #if DEBUG
                if textReplacementDecision.isFallbackNoMatch {
                    NSLog("[PHTV TextReplacement] ❌ NOT DETECTED - Will process normally (code=%d, backspace=%d, newChar=%d) - MAY CAUSE DUPLICATE!",
                          PHTVEngineRuntimeFacade.engineDataCode(), PHTVEngineRuntimeFacade.engineDataBackspaceCount(),
                          PHTVEngineRuntimeFacade.engineDataNewCharCount())
                }
                #endif
            }

            let characterSendPlan = PHTVInputStrategyService.characterSendPlan(
                forSpotlightTarget: isSpotlightTarget,
                cliTarget: PHTVEventRuntimeContextService.isCliTargetEnabled(),
                globalStepByStep: PHTVEngineRuntimeFacade.isSendKeyStepByStepEnabled(),
                appNeedsStepByStep: appChars.needsStepByStep,
                keyCode: Int32(eventKeycode),
                engineCode: Int32(PHTVEngineRuntimeFacade.engineDataCode()),
                restoreCode: Int32(PHTVEngineRuntimeFacade.engineRestoreCode()),
                restoreAndStartNewSessionCode: Int32(PHTVEngineRuntimeFacade.engineRestoreAndStartNewSessionCode()),
                enterKeyCode: Int32(PHTVEngineRuntimeFacade.keyEnterCode()),
                returnKeyCode: Int32(PHTVEngineRuntimeFacade.keyReturnCode()))

            // Send backspace
            let bsCount = Int(PHTVEngineRuntimeFacade.engineDataBackspaceCount())
            if bsCount > 0 && bsCount < Int(PHTVEngineRuntimeFacade.engineMaxBuffer()) {
                if characterSendPlan.deferBackspaceToAX {
                    PHTVEventRuntimeContextService.setPendingBackspaceCount(Int32(bsCount))
                    #if DEBUG
                    PHTVSpotlightDetectionService.emitRuntimeDebugLog(
                        "deferBackspace=\(bsCount) newCharCount=\(PHTVEngineRuntimeFacade.engineDataNewCharCount())",
                        throttleMs: kDebugLogThrottleMs)
                    #endif
                } else {
                    PHTVKeyEventSenderService.sendBackspaceSequenceWithDelay(Int32(bsCount))
                }
            }

            // Send new character
            let useStepByStep = characterSendPlan.useStepByStepCharacterSend
            #if DEBUG
            if isSpotlightTarget {
                PHTVSpotlightDetectionService.emitRuntimeDebugLog(
                    "willSend stepByStep=\(useStepByStep ? 1 : 0) backspaceCount=\(PHTVEngineRuntimeFacade.engineDataBackspaceCount()) newCharCount=\(PHTVEngineRuntimeFacade.engineDataNewCharCount())",
                    throttleMs: kDebugLogThrottleMs)
            }
            #endif

            if !useStepByStep {
                PHTVCharacterOutputService.sendNewCharString(
                    dataFromMacro: false, offset: 0,
                    keycode: eventKeycode, flags: eventFlags.rawValue)
            } else {
                let newCharCount = Int(PHTVEngineRuntimeFacade.engineDataNewCharCount())
                if newCharCount > 0 && newCharCount <= Int(PHTVEngineRuntimeFacade.engineMaxBuffer()) {
                    let cliSpeedFactor = PHTVCliRuntimeStateService.currentSpeedFactor()
                    let isCli = PHTVEventRuntimeContextService.isCliTargetEnabled()
                    let scaledCliTextDelayUs: UInt64 = isCli
                        ? UInt64(PHTVTimingService.scaleDelayUseconds(
                            PHTVTimingService.clampToUseconds(
                                PHTVCliRuntimeStateService.cliTextDelayUs()),
                            factor: cliSpeedFactor))
                        : 0
                    let scaledCliPostSendBlockUs: UInt64 = isCli
                        ? PHTVTimingService.scaleDelayMicroseconds(
                            PHTVCliRuntimeStateService.cliPostSendBlockUs(),
                            factor: cliSpeedFactor)
                        : 0
                    let sendPlan = PHTVSendSequenceService.sequencePlan(
                        forCliTarget: isCli,
                        itemCount: Int32(newCharCount),
                        scaledCliTextDelayUs: Int64(scaledCliTextDelayUs),
                        scaledCliPostSendBlockUs: Int64(scaledCliPostSendBlockUs))
                    let interItemDelayUs = PHTVTimingService.clampToUseconds(
                        UInt64(max(Int64(0), sendPlan.interItemDelayUs)))

                    for i in stride(from: newCharCount - 1, through: 0, by: -1) {
                        PHTVKeyEventSenderService.sendKeyCode(PHTVEngineRuntimeFacade.engineDataCharAt(Int32(i)))
                        if interItemDelayUs > 0 && i > 0 {
                            usleep(interItemDelayUs)
                        }
                    }
                    if sendPlan.shouldScheduleCliBlock {
                        PHTVCliRuntimeStateService.scheduleBlock(
                            forMicroseconds: UInt64(max(Int64(0), sendPlan.cliBlockUs)),
                            nowMachTime: mach_absolute_time())
                    }
                }
                if characterSendPlan.shouldSendRestoreTriggerKey {
                    #if DEBUG
                    if Int(PHTVEngineRuntimeFacade.engineDataCode()) == PHTVEngineRuntimeFacade.engineRestoreAndStartNewSessionCode() {
                        fputs("[AutoEnglish] PROCESSING RESTORE: backspace=\(PHTVEngineRuntimeFacade.engineDataBackspaceCount()), newChar=\(PHTVEngineRuntimeFacade.engineDataNewCharCount())\n", stderr)
                    }
                    #endif
                    PHTVKeyEventSenderService.sendKeyCode(
                        UInt32(eventKeycode) |
                        ((eventFlags.contains(.maskAlphaShift) || eventFlags.contains(.maskShift))
                         ? PHTVEngineRuntimeFacade.capsMask() : 0))
                }
                if characterSendPlan.shouldStartNewSessionAfterSend {
                    PHTVEngineDataBridge.startNewSession()
                }
            }

        } else if signalAction == PHTVEngineSignalAction.replaceMacro.rawValue {
            PHTVCharacterOutputService.handleMacro(
                keycode: eventKeycode, flags: eventFlags.rawValue)
        }

        return nil
    }
}
