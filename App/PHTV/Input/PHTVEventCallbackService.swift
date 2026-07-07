//
//  PHTVEventCallbackService.swift
//  PHTV
//
//  Main event tap callback logic.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import ApplicationServices
import Darwin
import Foundation

struct PHTVEnglishUppercaseState {
    var pending: Bool
    var needsSpaceConfirm: Bool
    var ellipsisContinuation: Bool = false

    static let idle = PHTVEnglishUppercaseState(
        pending: false,
        needsSpaceConfirm: false,
        ellipsisContinuation: false
    )
}

final class PHTVEventCallbackService {

    // MARK: - Constants

    private static let kSpotlightCacheDurationMs: UInt64 = 150
    private static let kTextReplacementDeleteWindowMs: UInt64 = 30000
    private static let kAppCharacteristicsCacheMaxAgeMs: UInt64 = 10000
    private static let keyEventKeyboard: Int32 = Int32(PHTV_ENGINE_EVENT_KEYBOARD)
    private static let keyEventStateKeyDown: Int32 = Int32(PHTV_ENGINE_EVENT_STATE_KEY_DOWN)
    private final class EnglishUppercaseStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = PHTVEnglishUppercaseState.idle

        func withLock<T>(_ body: (inout PHTVEnglishUppercaseState) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    private static let englishUppercaseStateBox = EnglishUppercaseStateBox()
    #if DEBUG
    private static let kDebugLogThrottleMs: UInt64 = 500
    #endif

    // MARK: - English uppercase helpers

    @objc class func resetTransientStateForTapLifecycle() {
        englishUppercaseStateBox.withLock { state in
            state = .idle
        }
    }

    static func englishUppercaseTransition(
        state: PHTVEnglishUppercaseState,
        keyCode: UInt16,
        flags: CGEventFlags,
        uppercaseEnabled: Bool,
        uppercaseExcluded: Bool
    ) -> (nextState: PHTVEnglishUppercaseState, shouldForceUppercase: Bool) {
        guard uppercaseEnabled, !uppercaseExcluded else {
            return (.idle, false)
        }

        if isEnglishUppercaseBlockedModifier(flags) {
            return (state, false)
        }

        let hasShift = flags.contains(.maskShift)
        let hasCapsLock = flags.contains(.maskAlphaShift)
        let hasShiftOrCaps = hasShift || hasCapsLock

        if state.ellipsisContinuation {
            if keyCode == KEY_DOT || keyCode == KEY_SPACE {
                return (state, false)
            }
            return (.idle, false)
        }

        if let needsSpaceConfirm = englishUppercaseSentenceTerminatorSpaceRequirement(
            keyCode: keyCode,
            hasShift: hasShift
        ) {
            if state.pending && state.needsSpaceConfirm && keyCode == KEY_DOT && !hasShift {
                return (
                    PHTVEnglishUppercaseState(
                        pending: false,
                        needsSpaceConfirm: false,
                        ellipsisContinuation: true
                    ),
                    false
                )
            }
            return (
                PHTVEnglishUppercaseState(
                    pending: true,
                    needsSpaceConfirm: needsSpaceConfirm,
                    ellipsisContinuation: false
                ),
                false
            )
        }

        guard state.pending else {
            return (state, false)
        }

        if keyCode == KEY_SPACE {
            if state.needsSpaceConfirm {
                return (
                    PHTVEnglishUppercaseState(
                        pending: true,
                        needsSpaceConfirm: false,
                        ellipsisContinuation: false
                    ),
                    false
                )
            }
            return (state, false)
        }

        if isEnglishUppercaseSkippablePunctuation(keyCode: keyCode, hasShift: hasShift) {
            return (state, false)
        }

        if isEnglishLetterKeyCode(keyCode) {
            if state.needsSpaceConfirm {
                return (.idle, false)
            }
            return (.idle, !hasShiftOrCaps)
        }

        return (.idle, false)
    }

    private static func isEnglishUppercaseBlockedModifier(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskCommand)
            || flags.contains(.maskControl)
            || flags.contains(.maskAlternate)
            || flags.contains(.maskSecondaryFn)
            || flags.contains(.maskNumericPad)
            || flags.contains(.maskHelp)
    }

    private static func isEnglishLetterKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J,
             KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T,
             KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z:
            return true
        default:
            return false
        }
    }

    private static func isEnglishUppercaseSkippablePunctuation(keyCode: UInt16, hasShift: Bool) -> Bool {
        if keyCode == KEY_QUOTE || keyCode == KEY_LEFT_BRACKET || keyCode == KEY_RIGHT_BRACKET {
            return true
        }
        return hasShift && (keyCode == KEY_9 || keyCode == KEY_0)
    }

    private static func shouldStabilizeCliPassThroughKey(
        keyCode: CGKeyCode,
        flags: CGEventFlags
    ) -> Bool {
        PHTVInputStrategyService.shouldOwnCliPrintableKey(
            forCliTarget: true,
            printableKey: EngineMacroKeyMap.character(for: UInt32(keyCode)) != 0,
            otherControlKey: PHTVEventContextBridgeService.hasOtherControlKey(withFlags: flags.rawValue),
            navigationKey: EngineInputClassification.isNavigationKey(keyCode)
        )
    }

    private static func cliPrintableCodeUnit(
        from event: CGEvent,
        keyCode: CGKeyCode,
        flags: CGEventFlags
    ) -> UInt16? {
        guard shouldStabilizeCliPassThroughKey(keyCode: keyCode, flags: flags) else {
            return nil
        }

        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: chars.count,
            actualStringLength: &length,
            unicodeString: &chars
        )
        if length == 1, chars[0] != 0 {
            return chars[0]
        }

        let hasCaps = flags.contains(.maskShift) || flags.contains(.maskAlphaShift)
        let mapped = EngineMacroKeyMap.character(
            for: UInt32(keyCode) | (hasCaps ? EngineBitMask.caps : 0)
        )
        return mapped == 0 ? nil : mapped
    }

    private static func sendCliOwnedPrintableCodeUnit(_ codeUnit: UInt16) {
        var mutableCodeUnit = codeUnit
        withUnsafePointer(to: &mutableCodeUnit) { ptr in
            PHTVKeyEventSenderService.sendUnicodeStringChunked(
                ptr,
                len: 1,
                chunkSize: 1,
                interDelayUs: 0
            )
        }
    }

    private static func englishUppercaseSentenceTerminatorSpaceRequirement(
        keyCode: UInt16,
        hasShift: Bool
    ) -> Bool? {
        if keyCode == KEY_ENTER || keyCode == KEY_RETURN {
            return false
        }
        if keyCode == KEY_DOT && !hasShift {
            return true
        }
        if hasShift && (keyCode == KEY_SLASH || keyCode == KEY_1) {
            return true
        }
        return nil
    }

    private static func englishUppercasePrimeStateFromAX(
        keyCode: UInt16,
        hasShift: Bool
    ) -> PHTVEnglishUppercaseState? {
        if let needsSpaceConfirm = englishUppercaseSentenceTerminatorSpaceRequirement(
            keyCode: keyCode,
            hasShift: hasShift
        ) {
            return PHTVEnglishUppercaseState(
                pending: true,
                needsSpaceConfirm: needsSpaceConfirm,
                ellipsisContinuation: false
            )
        }

        if keyCode == KEY_SPACE
            || isEnglishUppercaseSkippablePunctuation(keyCode: keyCode, hasShift: hasShift) {
            return PHTVEnglishUppercaseState(
                pending: true,
                needsSpaceConfirm: false,
                ellipsisContinuation: false
            )
        }
        return nil
    }

    private static func applyForcedEnglishUppercase(
        to event: CGEvent,
        eventFlags: inout CGEventFlags,
        keyCode: UInt16
    ) {
        eventFlags.insert(.maskShift)
        event.flags = eventFlags

        let upperCharacter = EngineMacroKeyMap.character(
            for: UInt32(keyCode) | EngineBitMask.caps
        )
        guard upperCharacter != 0 else {
            return
        }

        var mutableUpperCharacter = upperCharacter
        event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &mutableUpperCharacter)
    }

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

        // Skip events injected by PHTV itself before CLI stabilization. Synthetic
        // events must not be delayed by the guard that protects real user input.
        if event.getIntegerValueField(.eventSourceUserData) == EventSourceMarker.phtv {
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

        if PHTVKeyboardCleaningService.shouldBlockKeyboardEvent(type: type) {
            return nil
        }

        // Perform periodic health check and recovery.
        let tapHealthOk = PHTVEventTapHealthService.checkAndRecover(forEventType: type)
        _ = tapHealthOk

        PHTVEventRuntimeContextService.clearCliPostFlags()
        var eventFlags = event.flags
        var eventKeycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        // One consistent settings view per event; avoids re-locking the
        // runtime-settings store for every field read below.
        let settings = PHTVEngineRuntimeFacade.eventDispatchSettingsSnapshot()
        let currentLanguage = settings.language
        let safeModeEnabled = settings.safeMode
        if currentLanguage != 0 {
            englishUppercaseStateBox.withLock { state in
                state = .idle
            }
        }
        var shouldPrimeUppercaseFromAX = false
        var cachedConvertHotkey: Int32?
        func currentConvertHotkey() -> Int32 {
            if let cachedConvertHotkey {
                return cachedConvertHotkey
            }
            let hotkey = PHTVConvertToolHotkeyService.currentHotkey()
            cachedConvertHotkey = hotkey
            return hotkey
        }

        // Track text-replacement keydown patterns (external DELETE and following SPACE).
        if type == .keyDown {
            PHTVTextReplacementDecisionService.handleKeyDownTextReplacementTracking(
                forKeyCode: Int32(eventKeycode),
                deleteKeyCode: Int32(KeyCode.delete),
                spaceKeyCode: Int32(KeyCode.space),
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
            let pauseKey = settings.pauseKey
            if PHTVHotkeyService.shouldStripPauseModifier(
                withFlags: eventFlags.rawValue,
                pauseKeyCode: pauseKey) {
                let newFlagsRaw = PHTVHotkeyService.stripPauseModifier(
                    forFlags: eventFlags.rawValue,
                    pauseKeyCode: pauseKey)
                event.flags = CGEventFlags(rawValue: newFlagsRaw)
            }
        }

        if type == .keyDown && settings.performLayoutCompat != 0 {
            eventKeycode = PHTVHotkeyService.convertEventToKeyboardLayoutCompatKeyCode(
                event, fallback: eventKeycode)
        }

        // Switch-language / quick-convert / emoji hotkey handling
        if type == .keyDown {
            let quickConvertHotkey = currentConvertHotkey()
            let hotkeyAction = PHTVEventContextBridgeService.processKeyDownHotkeyAndApplyState(
                forKeyCode: eventKeycode,
                currentFlags: eventFlags.rawValue,
                switchHotkey: settings.switchKeyStatus,
                switchHotkey2: settings.switchKey2Status,
                convertHotkey: quickConvertHotkey,
                emojiEnabled: settings.enableEmojiHotkey,
                emojiModifiers: settings.emojiHotkeyModifiers,
                emojiHotkeyKeyCode: settings.emojiHotkeyKeyCode)
            if hotkeyAction != PHTVKeyDownHotkeyAction.none.rawValue {
                if PHTVRuntimeUIBridgeService.handleKeyDownHotkeyActionFromRuntime(Int32(hotkeyAction)) {
                    PHTVModifierRuntimeStateService.setLastFlagsValue(0)
                    PHTVModifierRuntimeStateService.setHasJustUsedHotKeyValue(true)
                    return nil
                }
            }
        }

        if type == .keyDown {
            if settings.upperCaseFirstChar != 0 &&
               settings.upperCaseExcludedForCurrentApp == 0 {
                let keyWithCaps = UInt32(eventKeycode) |
                    ((eventFlags.contains(.maskShift) || eventFlags.contains(.maskAlphaShift))
                     ? EngineBitMask.caps : 0)
                let keyCharacter = EngineMacroKeyMap.character(for: keyWithCaps)
                let isNavigationKey = EngineInputClassification.isNavigationKey(eventKeycode)
                let shouldPrime = PHTVEventContextBridgeService.shouldPrimeUppercaseOnKeyDown(
                    withFlags: eventFlags.rawValue,
                    keyCode: eventKeycode,
                    keyCharacter: keyCharacter,
                    isNavigationKey: isNavigationKey,
                    safeMode: safeModeEnabled,
                    uppercaseEnabled: settings.upperCaseFirstChar,
                    uppercaseExcluded: settings.upperCaseExcludedForCurrentApp)
                if shouldPrime {
                    shouldPrimeUppercaseFromAX = true
                    if currentLanguage != 0 {
                        phtvEnginePrimeUpperCaseFirstChar()
                    }
                }
            }

            PHTVEventContextBridgeService.applyKeyDownModifierTracking(
                forFlags: eventFlags.rawValue,
                restoreOnEscape: settings.restoreOnEscape,
                customEscapeKey: settings.customEscapeKey,
                switchHotkey: settings.switchKeyStatus,
                switchHotkey2: settings.switchKey2Status,
                convertHotkey: currentConvertHotkey(),
                emojiEnabled: settings.enableEmojiHotkey,
                emojiModifiers: settings.emojiHotkeyModifiers,
                emojiHotkeyKeyCode: settings.emojiHotkeyKeyCode)

        } else if type == .flagsChanged {
            let lastFlags = PHTVModifierRuntimeStateService.lastFlagsValue()
            if lastFlags == 0 || lastFlags < eventFlags.rawValue {
                let pressResult = PHTVEventContextBridgeService.handleModifierPress(
                    withFlags: eventFlags.rawValue,
                    keyCode: eventKeycode,
                    restoreOnEscape: settings.restoreOnEscape,
                    customEscapeKey: settings.customEscapeKey,
                    pauseKeyEnabled: settings.pauseKeyEnabled,
                    pauseKeyCode: settings.pauseKey,
                    currentLanguage: currentLanguage,
                    switchHotkey: settings.switchKeyStatus,
                    switchHotkey2: settings.switchKey2Status)
                if pressResult.shouldUpdateLanguage {
                    PHTVEngineRuntimeFacade.setCurrentLanguage(pressResult.language)
                }
            } else if lastFlags > eventFlags.rawValue {
                let releaseResult = PHTVEventContextBridgeService.handleModifierRelease(
                    oldFlags: lastFlags,
                    newFlags: eventFlags.rawValue,
                    keyCode: eventKeycode,
                    restoreOnEscape: settings.restoreOnEscape,
                    customEscapeKey: settings.customEscapeKey,
                    switchHotkey: settings.switchKeyStatus,
                    switchHotkey2: settings.switchKey2Status,
                    convertHotkey: currentConvertHotkey(),
                    emojiEnabled: settings.enableEmojiHotkey,
                    emojiModifiers: settings.emojiHotkeyModifiers,
                    emojiKeyCode: settings.emojiHotkeyKeyCode,
                    tempOffSpellingEnabled: settings.tempOffSpelling,
                    tempOffEngineEnabled: settings.tempOffEngine,
                    pauseKeyEnabled: settings.pauseKeyEnabled,
                    pauseKeyCode: settings.pauseKey,
                    currentLanguage: currentLanguage)

                let shouldAttemptRestore = releaseResult.shouldAttemptRestore
                let releaseAction = Int(releaseResult.releaseAction)

                // Releasing modifiers - check for restore modifier key first
                if shouldAttemptRestore {
                    // Restore modifier released without any other key press - trigger restore
                    if phtvEngineRestoreToRawKeys() != 0 {
                        // Successfully restored - pData now contains restore info
                        // Send backspaces to delete Vietnamese characters
                        let bsCount = Int(PHTVEngineRuntimeFacade.engineDataBackspaceCount())
                        if bsCount > 0 && bsCount < Int(EngineSignalCode.maxBuffer) {
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

                if PHTVRuntimeUIBridgeService.handleModifierReleaseHotkeyActionFromRuntime(Int32(releaseAction)) {
                    PHTVModifierRuntimeStateService.setHasJustUsedHotKeyValue(true)
                    let shouldPassThroughReleaseEvent = PHTVHotkeyService.shouldPassThroughModifierReleaseEvent(
                        forReleaseAction: Int32(releaseAction),
                        switchHotkey: settings.switchKeyStatus,
                        switchHotkey2: settings.switchKey2Status,
                        convertHotkey: currentConvertHotkey(),
                        emojiEnabled: settings.enableEmojiHotkey,
                        emojiHotkeyKeyCode: settings.emojiHotkeyKeyCode
                    )
                    if shouldPassThroughReleaseEvent {
                        return Unmanaged.passRetained(event)
                    }
                    return nil
                }

                if releaseAction == PHTVModifierReleaseAction.tempOffSpelling.rawValue {
                    phtvEngineTempOffSpellChecking()
                } else if releaseAction == PHTVModifierReleaseAction.tempOffEngine.rawValue {
                    phtvEngineTempOff(1)
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

        // If is in English mode
        if currentLanguage == 0 {
            if type == .keyDown {
                let keyCode = UInt16(eventKeycode)
                let hasShift = eventFlags.contains(.maskShift)
                let hasCapsLock = eventFlags.contains(.maskAlphaShift)
                let uppercaseEnabled = settings.upperCaseFirstChar != 0
                let uppercaseExcluded = settings.upperCaseExcludedForCurrentApp != 0
                let currentUppercaseState = englishUppercaseStateBox.withLock { state in
                    state
                }
                let englishUppercaseTransitionResult = englishUppercaseTransition(
                    state: currentUppercaseState,
                    keyCode: keyCode,
                    flags: eventFlags,
                    uppercaseEnabled: uppercaseEnabled,
                    uppercaseExcluded: uppercaseExcluded
                )
                englishUppercaseStateBox.withLock { state in
                    state = englishUppercaseTransitionResult.nextState
                }

                let shouldApplyAXPrimeState =
                    shouldPrimeUppercaseFromAX
                    && uppercaseEnabled
                    && !uppercaseExcluded
                    && !isEnglishUppercaseBlockedModifier(eventFlags)
                    && !isEnglishLetterKeyCode(keyCode)

                if shouldApplyAXPrimeState,
                   let primedState = englishUppercasePrimeStateFromAX(
                    keyCode: keyCode,
                    hasShift: hasShift
                   ) {
                    englishUppercaseStateBox.withLock { state in
                        state = primedState
                    }
                }

                let canForceUppercaseByAXPrime =
                    shouldPrimeUppercaseFromAX
                    && uppercaseEnabled
                    && !uppercaseExcluded
                    && isEnglishLetterKeyCode(keyCode)
                    && !isEnglishUppercaseBlockedModifier(eventFlags)
                    && !hasShift
                    && !hasCapsLock

                if englishUppercaseTransitionResult.shouldForceUppercase || canForceUppercaseByAXPrime {
                    applyForcedEnglishUppercase(
                        to: event,
                        eventFlags: &eventFlags,
                        keyCode: keyCode
                    )
                    englishUppercaseStateBox.withLock { state in
                        state = .idle
                    }
                }
            }

            if settings.useMacro != 0 && settings.useMacroInEnglishMode != 0 &&
               type == .keyDown {
                phtvEngineHandleEnglishMode(
                    keyEventStateKeyDown,
                    eventKeycode,
                    (eventFlags.contains(.maskShift) || eventFlags.contains(.maskAlphaShift)) ? 1 : 0,
                    PHTVEventContextBridgeService.hasOtherControlKey(withFlags: eventFlags.rawValue) ? 1 : 0)

                if PHTVEngineRuntimeFacade.engineDataCode() == EngineSignalCode.replaceMacro {
                    _ = PHTVEventContextBridgeService.prepareTargetContextAndConfigureRuntime(
                        forEvent: event,
                        safeMode: safeModeEnabled,
                        spotlightCacheDurationMs: kSpotlightCacheDurationMs,
                        appCharacteristicsMaxAgeMs: kAppCharacteristicsCacheMaxAgeMs)
                    if PHTVCharacterOutputService.handleMacro(
                        keycode: eventKeycode, flags: eventFlags.rawValue)
                    {
                        return Unmanaged.passRetained(event)
                    }
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }

        // Handle mouse - reset session to avoid stale typing state
        if type == .leftMouseDown || type == .rightMouseDown {
            PHTVEngineSessionService.requestNewSessionInternal(allowUppercasePrime: true)
            PHTVModifierRuntimeStateService.setSingleModifierSwitchPressedKeyValue(0)
            PHTVModifierRuntimeStateService.setKeyPressedWhileSingleModifierHeldValue(false)
            return Unmanaged.passRetained(event)
        }

        // If "turn off Vietnamese when in other language" mode on
        if settings.otherLanguage != 0 {
            if !PHTVInputSourceLanguageService.shouldAllowVietnameseForOtherLanguageMode() {
                return Unmanaged.passRetained(event)
            }
        }

        // Handle keyboard
        if type == .keyDown {
            return handleKeyDown(proxy: proxy,
                                 event: event,
                                 eventKeycode: eventKeycode,
                                 eventFlags: eventFlags,
                                 settings: settings)
        }

        return Unmanaged.passRetained(event)
    }

    // MARK: - KeyDown processing

    private static func handleKeyDown(proxy: CGEventTapProxy,
                                      event: CGEvent,
                                      eventKeycode: CGKeyCode,
                                      eventFlags: CGEventFlags,
                                      settings: PHTVEventDispatchSettings) -> Unmanaged<CGEvent>? {
        let safeModeEnabled = settings.safeMode
        let targetContext = PHTVEventContextBridgeService.prepareTargetContextAndConfigureRuntime(
            forEvent: event,
            safeMode: safeModeEnabled,
            spotlightCacheDurationMs: kSpotlightCacheDurationMs,
            appCharacteristicsMaxAgeMs: kAppCharacteristicsCacheMaxAgeMs)
        let spotlightActive = targetContext.spotlightActive
        let effectiveBundleId = targetContext.effectiveBundleId
        let appChars = targetContext.appCharacteristics

        if PHTVAppContextService.shouldDisableVietnamese(forBundleId: effectiveBundleId) {
            return Unmanaged.passRetained(event)
        }

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
        let effectiveCodeTable = codeTableOverrideActive ? Int32(0) : currentCodeTable

        // Send event signal to Engine
        let capsStatus: UInt8 = eventFlags.contains(.maskShift) ? 1
            : (eventFlags.contains(.maskAlphaShift) ? 2 : 0)
        phtvEngineHandleEvent(
            keyEventKeyboard,
            keyEventStateKeyDown,
            eventKeycode,
            capsStatus,
            PHTVEventContextBridgeService.hasOtherControlKey(withFlags: eventFlags.rawValue) ? 1 : 0)

        // Capture engine output once; avoids re-locking the engine for every
        // field read below. Backspace-count adjustments later in this function
        // are tracked via locals alongside the engine-state mutation.
        let hookData = PHTVEngineRuntimeFacade.engineDataResultSnapshot()

        #if DEBUG
        if eventKeycode == CGKeyCode(KeyCode.space) {
            NSLog("[TextReplacement] Engine result for SPACE: code=%d, extCode=%d, backspace=%d, newChar=%d",
                  hookData.code, hookData.extCode,
                  hookData.backspaceCount, hookData.newCharCount)
        }
        if hookData.extCode == 5 {
            if hookData.code == EngineSignalCode.restore ||
               hookData.code == EngineSignalCode.restoreAndStartNewSession {
                NSLog("[AutoEnglish] ✓ RESTORE TRIGGERED: code=%d, backspace=%d, newChar=%d, keycode=%d (0x%X)",
                      hookData.code, hookData.backspaceCount,
                      hookData.newCharCount, eventKeycode, eventKeycode)
            } else {
                NSLog("[AutoEnglish] ⚠️ WARNING: extCode=5 but code=%d (not restore!)", hookData.code)
            }
        } else if eventKeycode == CGKeyCode(KeyCode.space) &&
                  hookData.code == EngineSignalCode.doNothing {
            NSLog("[AutoEnglish] ✗ NO RESTORE on SPACE: code=%d, extCode=%d",
                  hookData.code, hookData.extCode)
        }
        #endif

        let signalAction = Int(PHTVInputStrategyService.engineSignalAction(
            forEngineCode: hookData.code,
            doNothingCode: EngineSignalCode.doNothing,
            willProcessCode: EngineSignalCode.willProcess,
            restoreCode: EngineSignalCode.restore,
            restoreAndStartNewSessionCode: EngineSignalCode.restoreAndStartNewSession,
            replaceMacroCode: EngineSignalCode.replaceMacro))

        if signalAction == PHTVEngineSignalAction.doNothing.rawValue {
            // Navigation keys: trigger session restore to support keyboard-based edit-in-place
            if EngineInputClassification.isNavigationKey(eventKeycode) {
                // TryToRestoreSessionFromAX -- commented out
            }

            let shouldSendExtraBackspace =
                PHTVEventContextBridgeService.applyDoNothingSyncStateTransition(
                    forCodeTable: effectiveCodeTable,
                    extCode: hookData.extCode,
                    containsUnicodeCompound: appChars.containsUnicodeCompound)
            if shouldSendExtraBackspace {
                PHTVKeyEventSenderService.sendPhysicalBackspace()
            }
            if targetContext.isCliTarget,
               let cliCodeUnit = cliPrintableCodeUnit(
                from: event,
                keyCode: eventKeycode,
                flags: eventFlags
               ) {
                sendCliOwnedPrintableCodeUnit(cliCodeUnit)
                return nil
            }
            return Unmanaged.passRetained(event)

        } else if signalAction == PHTVEngineSignalAction.processSignal.rawValue {
            let isBrowserApp = targetContext.isBrowser
            let isSpotlightTarget = targetContext.postToHIDTap
            let processSignalPlan = PHTVInputStrategyService.processSignalPlan(
                forBundleId: effectiveBundleId,
                keyCode: Int32(eventKeycode),
                spaceKeyCode: Int32(KeyCode.space),
                slashKeyCode: Int32(KeyCode.slash),
                extCode: hookData.extCode,
                backspaceCount: hookData.backspaceCount,
                newCharCount: hookData.newCharCount,
                isBrowserApp: isBrowserApp,
                isSpotlightTarget: isSpotlightTarget,
                needsPrecomposedBatched: appChars.needsPrecomposedBatched,
                browserFixEnabled: settings.fixRecommendBrowser != 0)

            // FIGMA FIX: Force pass-through for Space key to support "Hand tool" (Hold Space)
            if processSignalPlan.shouldBypassForFigma {
                return Unmanaged.passRetained(event)
            }

            #if DEBUG
            if hookData.code == EngineSignalCode.restoreAndStartNewSession {
                fputs("[AutoEnglish] vRestoreAndStartNewSession START: backspace=\(hookData.backspaceCount), newChar=\(hookData.newCharCount), keycode=\(eventKeycode)\n", stderr)
            }
            #endif

            #if DEBUG
            let isSpotlightTargetDbg = processSignalPlan.isSpecialApp
            let isBrowserFix = processSignalPlan.isBrowserFix
            NSLog("[BrowserFix] Status: vFix=%d, app=%@, isBrowser=%d => isFix=%d | bs=%d, ext=%d",
                  settings.fixRecommendBrowser, effectiveBundleId ?? "",
                  isBrowserApp ? 1 : 0, isBrowserFix ? 1 : 0,
                  hookData.backspaceCount, hookData.extCode)
            if isBrowserFix && hookData.backspaceCount > 0 {
                NSLog("[BrowserFix] Checking logic: fix=%d, ext=%d, special=%d, skipSp=%d, shortcut=%d, bs=%d",
                      isBrowserFix ? 1 : 0, hookData.extCode,
                      isSpotlightTargetDbg ? 1 : 0,
                      processSignalPlan.shouldSkipSpace ? 1 : 0,
                      processSignalPlan.isPotentialShortcut ? 1 : 0,
                      hookData.backspaceCount)
            }
            #endif

            var isAddrBar = false
            if processSignalPlan.shouldTryBrowserAddressBarFix {
                isAddrBar = PHTVEventContextBridgeService.isFocusedElementAddressBar(
                    forSafeMode: safeModeEnabled)
                #if DEBUG
                NSLog("[BrowserFix] isFocusedElementAddressBar returned: %d", isAddrBar ? 1 : 0)
                #endif
            }

            let shouldInspectNotionCodeBlock =
                hookData.backspaceCount > 0 &&
                hookData.extCode != 4 &&
                (!processSignalPlan.isSpecialApp || processSignalPlan.isNotionApp) &&
                !processSignalPlan.isPotentialShortcut
            var isNotionCodeBlockDetected = false
            if shouldInspectNotionCodeBlock {
                isNotionCodeBlockDetected = PHTVEventContextBridgeService.isNotionCodeBlock(
                    forSafeMode: safeModeEnabled)
                #if DEBUG
                if isNotionCodeBlockDetected {
                    NSLog("[Notion] Code Block detected - using selection-overwrite backspace fix")
                }
                #endif
            }

            let shouldApplyLegacyBackspaceFix =
                processSignalPlan.shouldTryLegacyNonBrowserFix || isNotionCodeBlockDetected

            let resolvedBackspacePlan = PHTVInputStrategyService.resolvedBackspacePlan(
                forBrowserAddressBarFix: processSignalPlan.shouldTryBrowserAddressBarFix,
                addressBarDetected: isAddrBar,
                legacyNonBrowserFix: shouldApplyLegacyBackspaceFix,
                containsUnicodeCompound: appChars.containsUnicodeCompound,
                notionCodeBlockDetected: isNotionCodeBlockDetected,
                backspaceCount: hookData.backspaceCount,
                maxBuffer: EngineSignalCode.maxBuffer,
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

            let adjustedBackspaceCount = resolvedBackspacePlan.sanitizedBackspaceCount
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
                    spaceKeyCode: Int32(KeyCode.space),
                    backspaceCount: Int32(adjustedBackspaceCount),
                    newCharCount: hookData.newCharCount)

            #if DEBUG
            if shouldEvaluateTextReplacement {
                NSLog("[PHTV TextReplacement] Key=%d: code=%d, extCode=%d, backspace=%d, newChar=%d, deleteCount=%d",
                      eventKeycode, hookData.code, hookData.extCode,
                      adjustedBackspaceCount, hookData.newCharCount,
                      externalDeleteCount)
            }
            #endif

            if shouldEvaluateTextReplacement {
                let textReplacementDecision = PHTVTextReplacementDecisionService.evaluate(
                    forSpaceKey: true,
                    code: hookData.code,
                    extCode: hookData.extCode,
                    backspaceCount: Int32(adjustedBackspaceCount),
                    newCharCount: hookData.newCharCount,
                    externalDeleteCount: externalDeleteCount,
                    restoreAndStartNewSessionCode: EngineSignalCode.restoreAndStartNewSession,
                    willProcessCode: EngineSignalCode.willProcess,
                    restoreCode: EngineSignalCode.restore,
                    deleteWindowMs: kTextReplacementDeleteWindowMs)

                if textReplacementDecision.shouldBypassEvent {
                    #if DEBUG
                    if textReplacementDecision.isExternalDelete {
                        NSLog("[TextReplacement] Text replacement detected - passing through event (code=%d, backspace=%d, newChar=%d, deleteCount=%d, elapsedMs=%llu)",
                              hookData.code, adjustedBackspaceCount,
                              hookData.newCharCount, externalDeleteCount,
                              textReplacementDecision.matchedElapsedMs)
                    } else if textReplacementDecision.isPatternMatch {
                        NSLog("[PHTV TextReplacement] Pattern %@ matched: code=%d, backspace=%d, newChar=%d, keycode=%d",
                              textReplacementDecision.patternLabel ?? "?",
                              hookData.code, adjustedBackspaceCount,
                              hookData.newCharCount, eventKeycode)
                        NSLog("[PHTV TextReplacement] ✅ DETECTED - Skipping processing (code=%d, backspace=%d, newChar=%d)",
                              hookData.code, adjustedBackspaceCount,
                              hookData.newCharCount)
                    }
                    #endif
                    // CRITICAL: Return event to let macOS insert Space
                    return Unmanaged.passRetained(event)
                }

                #if DEBUG
                if textReplacementDecision.isFallbackNoMatch {
                    NSLog("[PHTV TextReplacement] ❌ NOT DETECTED - Will process normally (code=%d, backspace=%d, newChar=%d) - MAY CAUSE DUPLICATE!",
                          hookData.code, adjustedBackspaceCount,
                          hookData.newCharCount)
                }
                #endif
            }

            let characterSendPlan = PHTVInputStrategyService.characterSendPlan(
                forSpotlightTarget: isSpotlightTarget,
                cliTarget: PHTVEventRuntimeContextService.isCliTargetEnabled(),
                globalStepByStep: settings.sendKeyStepByStep,
                appNeedsStepByStep: appChars.needsStepByStep,
                appNeedsPrecomposedBatched: appChars.needsPrecomposedBatched,
                keyCode: Int32(eventKeycode),
                engineCode: hookData.code,
                restoreCode: EngineSignalCode.restore,
                restoreAndStartNewSessionCode: EngineSignalCode.restoreAndStartNewSession,
                enterKeyCode: Int32(KeyCode.enter),
                returnKeyCode: Int32(KeyCode.returnKey))

            // Send backspace
            let bsCount = adjustedBackspaceCount
            if bsCount > 0 && bsCount < EngineSignalCode.maxBuffer {
                if characterSendPlan.deferBackspaceToAX {
                    PHTVEventRuntimeContextService.setPendingBackspaceCount(bsCount)
                    #if DEBUG
                    PHTVSpotlightDetectionService.emitRuntimeDebugLog(
                        "deferBackspace=\(bsCount) newCharCount=\(hookData.newCharCount)",
                        throttleMs: kDebugLogThrottleMs)
                    #endif
                } else {
                    PHTVKeyEventSenderService.sendBackspaceSequenceWithDelay(bsCount)
                }
            }

            // Send new character
            let useStepByStep = characterSendPlan.useStepByStepCharacterSend
            #if DEBUG
            if isSpotlightTarget {
                PHTVSpotlightDetectionService.emitRuntimeDebugLog(
                    "willSend stepByStep=\(useStepByStep ? 1 : 0) backspaceCount=\(adjustedBackspaceCount) newCharCount=\(hookData.newCharCount)",
                    throttleMs: kDebugLogThrottleMs)
            }
            #endif

            if !useStepByStep {
                PHTVCharacterOutputService.sendNewCharString(
                    dataFromMacro: false, offset: 0,
                    keycode: eventKeycode, flags: eventFlags.rawValue)
            } else {
                let newCharCount = Int(hookData.newCharCount)
                if newCharCount > 0 && newCharCount <= Int(EngineSignalCode.maxBuffer) {
                    PHTVSendSequenceService.sendItemsStepByStep(count: newCharCount) { index in
                        PHTVKeyEventSenderService.sendKeyCode(
                            hookData.char(at: newCharCount - 1 - index))
                    }
                }
                if characterSendPlan.shouldSendRestoreTriggerKey {
                    #if DEBUG
                    if hookData.code == EngineSignalCode.restoreAndStartNewSession {
                        fputs("[AutoEnglish] PROCESSING RESTORE: backspace=\(adjustedBackspaceCount), newChar=\(hookData.newCharCount)\n", stderr)
                    }
                    #endif
                    PHTVKeyEventSenderService.sendKeyCode(
                        UInt32(eventKeycode) |
                        ((eventFlags.contains(.maskAlphaShift) || eventFlags.contains(.maskShift))
                         ? EngineBitMask.caps : 0))
                }
                if characterSendPlan.shouldStartNewSessionAfterSend {
                    PHTVEngineDataBridge.startNewSession()
                }
            }

        } else if signalAction == PHTVEngineSignalAction.replaceMacro.rawValue {
            if PHTVCharacterOutputService.handleMacro(
                keycode: eventKeycode, flags: eventFlags.rawValue)
            {
                return Unmanaged.passRetained(event)
            }
        }

        return nil
    }
}
