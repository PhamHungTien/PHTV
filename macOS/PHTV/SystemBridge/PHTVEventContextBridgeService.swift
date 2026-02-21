//
//  PHTVEventContextBridgeService.swift
//  PHTV
//
//  Consolidates Accessibility and Spotlight helper calls for PHTV.mm.
//

import ApplicationServices
import Foundation
import Darwin

@objcMembers
final class PHTVModifierTransitionResultBox: NSObject {
    let shouldAttemptRestore: Bool
    let releaseAction: Int32
    let shouldUpdateLanguage: Bool
    let language: Int32

    init(shouldAttemptRestore: Bool,
         releaseAction: Int32,
         shouldUpdateLanguage: Bool,
         language: Int32) {
        self.shouldAttemptRestore = shouldAttemptRestore
        self.releaseAction = releaseAction
        self.shouldUpdateLanguage = shouldUpdateLanguage
        self.language = language
    }
}

@objcMembers
final class PHTVEventContextBridgeService: NSObject {
    @objc(invalidateAccessibilityContextCaches)
    class func invalidateAccessibilityContextCaches() {
        PHTVAccessibilityService.invalidateContextDetectionCaches()
    }

    @objc(replaceFocusedTextViaAXWithBackspaceCount:insertText:verify:safeMode:)
    class func replaceFocusedTextViaAX(backspaceCount: Int32,
                                       insertText: String?,
                                       verify: Bool,
                                       safeMode: Bool) -> Bool {
        guard !safeMode else {
            return false
        }
        return PHTVAccessibilityService.replaceFocusedTextViaAX(Int(backspaceCount),
                                                                insertText: insertText,
                                                                verify: verify)
    }

    @objc(isFocusedElementAddressBarForSafeMode:)
    class func isFocusedElementAddressBar(forSafeMode safeMode: Bool) -> Bool {
        guard !safeMode else {
            return false
        }
        return PHTVAccessibilityService.isFocusedElementAddressBar()
    }

    @objc(isNotionCodeBlockForSafeMode:)
    class func isNotionCodeBlock(forSafeMode safeMode: Bool) -> Bool {
        guard !safeMode else {
            return false
        }
        return PHTVAccessibilityService.isNotionCodeBlock()
    }

    @objc(handleSpotlightCacheInvalidationForType:keycode:flags:)
    class func handleSpotlightCacheInvalidation(forType type: CGEventType,
                                                keycode: UInt16,
                                                flags: CGEventFlags) {
        PHTVSpotlightDetectionService.handleSpotlightCacheInvalidation(type,
                                                                       keycode: CGKeyCode(keycode),
                                                                       flags: flags)
    }

    @objc(configureSyntheticKeyEventsWithKeyDown:keyUp:eventMarker:)
    class func configureSyntheticKeyEvents(withKeyDown keyDown: CGEvent,
                                           keyUp: CGEvent,
                                           eventMarker: Int64) {
        let keyboardType = PHTVEventRuntimeContextService.currentKeyboardTypeValue()
        if keyboardType != 0 {
            keyDown.setIntegerValueField(.keyboardEventKeyboardType, value: keyboardType)
            keyUp.setIntegerValueField(.keyboardEventKeyboardType, value: keyboardType)
        }

        var normalizedFlags = keyDown.flags
        normalizedFlags.insert(.maskNonCoalesced)
        normalizedFlags.remove(.maskSecondaryFn)

        keyDown.flags = normalizedFlags
        keyUp.flags = normalizedFlags
        keyDown.setIntegerValueField(.eventSourceUserData, value: eventMarker)
        keyUp.setIntegerValueField(.eventSourceUserData, value: eventMarker)
    }

    @objc(trackExternalDelete)
    class func trackExternalDelete() {
        PHTVSpotlightDetectionService.trackExternalDelete()
    }

    @objc(externalDeleteCountValue)
    class func externalDeleteCountValue() -> Int32 {
        Int32(PHTVSpotlightDetectionService.externalDeleteCountValue())
    }

    @objc(elapsedSinceLastExternalDeleteMs)
    class func elapsedSinceLastExternalDeleteMs() -> UInt64 {
        PHTVSpotlightDetectionService.elapsedSinceLastExternalDeleteMs()
    }

    @objc(shouldDisableVietnameseForEvent:safeMode:cacheDurationMs:spotlightCacheDurationMs:)
    class func shouldDisableVietnamese(forEvent event: CGEvent,
                                       safeMode: Bool,
                                       cacheDurationMs: UInt64,
                                       spotlightCacheDurationMs: UInt64) -> Bool {
        let targetPID = Int32(event.getIntegerValueField(.eventTargetUnixProcessID))
        return PHTVAppContextService.shouldDisableVietnamese(
            forTargetPid: targetPID,
            cacheDurationMs: cacheDurationMs,
            safeMode: safeMode,
            spotlightCacheDurationMs: spotlightCacheDurationMs
        )
    }

    @objc(prepareTargetContextAndConfigureRuntimeForEvent:safeMode:spotlightCacheDurationMs:appCharacteristicsMaxAgeMs:)
    class func prepareTargetContextAndConfigureRuntime(forEvent event: CGEvent,
                                                       safeMode: Bool,
                                                       spotlightCacheDurationMs: UInt64,
                                                       appCharacteristicsMaxAgeMs: UInt64) -> PHTVEventTargetContextBox {
        let eventTargetPID = Int32(event.getIntegerValueField(.eventTargetUnixProcessID))
        let targetContext = PHTVAppContextService.eventTargetContext(
            forEventTargetPid: eventTargetPID,
            safeMode: safeMode,
            spotlightCacheDurationMs: spotlightCacheDurationMs,
            appCharacteristicsMaxAgeMs: appCharacteristicsMaxAgeMs
        )

        let appCharacteristics = targetContext.appCharacteristics
        let keyboardType = event.getIntegerValueField(.keyboardEventKeyboardType)
        PHTVEventRuntimeContextService.configure(
            from: targetContext,
            appCharacteristics: appCharacteristics,
            keyboardType: keyboardType
        )

        if targetContext.isCliTarget {
            PHTVCliRuntimeStateService.applyProfile(targetContext.cliTimingProfile)
            PHTVCliRuntimeStateService.updateSpeedFactor(forNowMachTime: mach_absolute_time())
        } else {
            PHTVCliRuntimeStateService.applyProfile(nil)
            PHTVCliRuntimeStateService.resetSpeedState()
        }

        return targetContext
    }

    @objc(handleModifierPressWithFlags:restoreOnEscape:customEscapeKey:pauseKeyEnabled:pauseKeyCode:currentLanguage:)
    class func handleModifierPress(withFlags flags: UInt64,
                                   restoreOnEscape: Int32,
                                   customEscapeKey: Int32,
                                   pauseKeyEnabled: Int32,
                                   pauseKeyCode: Int32,
                                   currentLanguage: Int32) -> PHTVModifierTransitionResultBox {
        let transition = PHTVHotkeyService.modifierPressTransition(
            forFlags: flags,
            restoreOnEscape: restoreOnEscape,
            customEscapeKey: customEscapeKey,
            keyPressedWithRestoreModifier: PHTVModifierRuntimeStateService.keyPressedWithRestoreModifierValue(),
            restoreModifierPressed: PHTVModifierRuntimeStateService.restoreModifierPressedValue(),
            pauseKeyEnabled: pauseKeyEnabled,
            pauseKeyCode: pauseKeyCode,
            pausePressed: PHTVModifierRuntimeStateService.pausePressedValue(),
            currentLanguage: currentLanguage,
            savedLanguage: PHTVModifierRuntimeStateService.savedLanguageValue()
        )

        PHTVModifierRuntimeStateService.setLastFlagsValue(transition.lastFlags)
        PHTVModifierRuntimeStateService.setKeyPressedWithRestoreModifierValue(transition.keyPressedWithRestoreModifier)
        PHTVModifierRuntimeStateService.setRestoreModifierPressedValue(transition.restoreModifierPressed)
        PHTVModifierRuntimeStateService.setKeyPressedWhileSwitchModifiersHeldValue(transition.keyPressedWhileSwitchModifiersHeld)
        PHTVModifierRuntimeStateService.setKeyPressedWhileEmojiModifiersHeldValue(transition.keyPressedWhileEmojiModifiersHeld)
        PHTVModifierRuntimeStateService.setPausePressedValue(transition.pausePressed)
        PHTVModifierRuntimeStateService.setSavedLanguageValue(transition.savedLanguage)

        return PHTVModifierTransitionResultBox(
            shouldAttemptRestore: false,
            releaseAction: PHTVModifierReleaseAction.none.rawValue,
            shouldUpdateLanguage: transition.shouldUpdateLanguage,
            language: transition.language
        )
    }

    @objc(handleModifierReleaseWithOldFlags:newFlags:restoreOnEscape:customEscapeKey:switchHotkey:convertHotkey:emojiEnabled:emojiModifiers:emojiKeyCode:tempOffSpellingEnabled:tempOffEngineEnabled:pauseKeyEnabled:pauseKeyCode:currentLanguage:)
    class func handleModifierRelease(oldFlags: UInt64,
                                     newFlags: UInt64,
                                     restoreOnEscape: Int32,
                                     customEscapeKey: Int32,
                                     switchHotkey: Int32,
                                     convertHotkey: Int32,
                                     emojiEnabled: Int32,
                                     emojiModifiers: Int32,
                                     emojiKeyCode: Int32,
                                     tempOffSpellingEnabled: Int32,
                                     tempOffEngineEnabled: Int32,
                                     pauseKeyEnabled: Int32,
                                     pauseKeyCode: Int32,
                                     currentLanguage: Int32) -> PHTVModifierTransitionResultBox {
        let transition = PHTVHotkeyService.modifierReleaseTransition(
            restoreOnEscape: restoreOnEscape,
            restoreModifierPressed: PHTVModifierRuntimeStateService.restoreModifierPressedValue(),
            keyPressedWithRestoreModifier: PHTVModifierRuntimeStateService.keyPressedWithRestoreModifierValue(),
            customEscapeKey: customEscapeKey,
            oldFlags: oldFlags,
            newFlags: newFlags,
            switchHotkey: switchHotkey,
            convertHotkey: convertHotkey,
            emojiEnabled: emojiEnabled,
            emojiModifiers: emojiModifiers,
            emojiKeyCode: emojiKeyCode,
            keyPressedWhileSwitchModifiersHeld: PHTVModifierRuntimeStateService.keyPressedWhileSwitchModifiersHeldValue(),
            keyPressedWhileEmojiModifiersHeld: PHTVModifierRuntimeStateService.keyPressedWhileEmojiModifiersHeldValue(),
            hasJustUsedHotkey: PHTVModifierRuntimeStateService.hasJustUsedHotKeyValue(),
            tempOffSpellingEnabled: tempOffSpellingEnabled,
            tempOffEngineEnabled: tempOffEngineEnabled,
            pauseKeyEnabled: pauseKeyEnabled,
            pauseKeyCode: pauseKeyCode,
            pausePressed: PHTVModifierRuntimeStateService.pausePressedValue(),
            currentLanguage: currentLanguage,
            savedLanguage: PHTVModifierRuntimeStateService.savedLanguageValue()
        )

        PHTVModifierRuntimeStateService.setRestoreModifierPressedValue(transition.restoreModifierPressed)
        PHTVModifierRuntimeStateService.setKeyPressedWithRestoreModifierValue(transition.keyPressedWithRestoreModifier)
        PHTVModifierRuntimeStateService.setSavedLanguageValue(transition.savedLanguage)
        PHTVModifierRuntimeStateService.setPausePressedValue(transition.pausePressed)
        PHTVModifierRuntimeStateService.setLastFlagsValue(transition.lastFlags)
        PHTVModifierRuntimeStateService.setKeyPressedWhileSwitchModifiersHeldValue(transition.keyPressedWhileSwitchModifiersHeld)
        PHTVModifierRuntimeStateService.setKeyPressedWhileEmojiModifiersHeldValue(transition.keyPressedWhileEmojiModifiersHeld)

        return PHTVModifierTransitionResultBox(
            shouldAttemptRestore: transition.shouldAttemptRestore,
            releaseAction: transition.releaseAction,
            shouldUpdateLanguage: transition.shouldUpdateLanguage,
            language: transition.language
        )
    }

    @objc(processKeyDownHotkeyAndApplyStateForKeyCode:currentFlags:switchHotkey:convertHotkey:emojiEnabled:emojiModifiers:emojiHotkeyKeyCode:)
    class func processKeyDownHotkeyAndApplyState(forKeyCode keyCode: UInt16,
                                                 currentFlags: UInt64,
                                                 switchHotkey: Int32,
                                                 convertHotkey: Int32,
                                                 emojiEnabled: Int32,
                                                 emojiModifiers: Int32,
                                                 emojiHotkeyKeyCode: Int32) -> Int32 {
        let evaluation = PHTVHotkeyService.processKeyDownHotkey(
            withKeyCode: keyCode,
            lastFlags: PHTVModifierRuntimeStateService.lastFlagsValue(),
            currentFlags: currentFlags,
            switchHotkey: switchHotkey,
            convertHotkey: convertHotkey,
            emojiEnabled: emojiEnabled,
            emojiModifiers: emojiModifiers,
            emojiHotkeyKeyCode: emojiHotkeyKeyCode
        )

        PHTVModifierRuntimeStateService.setLastFlagsValue(evaluation.lastFlags)
        PHTVModifierRuntimeStateService.setHasJustUsedHotKeyValue(evaluation.hasJustUsedHotKey)
        return evaluation.action
    }

    @objc(applyKeyDownModifierTrackingForFlags:restoreOnEscape:customEscapeKey:switchHotkey:convertHotkey:emojiEnabled:emojiModifiers:emojiHotkeyKeyCode:)
    class func applyKeyDownModifierTracking(forFlags flags: UInt64,
                                            restoreOnEscape: Int32,
                                            customEscapeKey: Int32,
                                            switchHotkey: Int32,
                                            convertHotkey: Int32,
                                            emojiEnabled: Int32,
                                            emojiModifiers: Int32,
                                            emojiHotkeyKeyCode: Int32) {
        let tracking = PHTVHotkeyService.keyDownModifierTracking(
            forFlags: flags,
            restoreOnEscape: restoreOnEscape,
            customEscapeKey: customEscapeKey,
            restoreModifierPressed: PHTVModifierRuntimeStateService.restoreModifierPressedValue(),
            keyPressedWithRestoreModifier: PHTVModifierRuntimeStateService.keyPressedWithRestoreModifierValue(),
            switchHotkey: switchHotkey,
            convertHotkey: convertHotkey,
            keyPressedWhileSwitchModifiersHeld: PHTVModifierRuntimeStateService.keyPressedWhileSwitchModifiersHeldValue(),
            emojiEnabled: emojiEnabled,
            emojiModifiers: emojiModifiers,
            emojiHotkeyKeyCode: emojiHotkeyKeyCode,
            keyPressedWhileEmojiModifiersHeld: PHTVModifierRuntimeStateService.keyPressedWhileEmojiModifiersHeldValue()
        )

        PHTVModifierRuntimeStateService.setKeyPressedWithRestoreModifierValue(tracking.keyPressedWithRestoreModifier)
        PHTVModifierRuntimeStateService.setKeyPressedWhileSwitchModifiersHeldValue(tracking.keyPressedWhileSwitchModifiersHeld)
        PHTVModifierRuntimeStateService.setKeyPressedWhileEmojiModifiersHeldValue(tracking.keyPressedWhileEmojiModifiersHeld)
    }

    @objc(shouldPrimeUppercaseOnKeyDownWithFlags:keyCode:keyCharacter:isNavigationKey:safeMode:uppercaseEnabled:uppercaseExcluded:)
    class func shouldPrimeUppercaseOnKeyDown(withFlags flags: UInt64,
                                             keyCode: UInt16,
                                             keyCharacter: UInt16,
                                             isNavigationKey: Bool,
                                             safeMode: Bool,
                                             uppercaseEnabled: Int32,
                                             uppercaseExcluded: Int32) -> Bool {
        guard uppercaseEnabled != 0, uppercaseExcluded == 0 else {
            return false
        }

        let transition = PHTVHotkeyService.uppercasePrimeTransition(
            forPending: PHTVModifierRuntimeStateService.pendingUppercasePrimeCheckValue(),
            flags: flags,
            keyCode: keyCode,
            keyCharacter: keyCharacter,
            isNavigationKey: isNavigationKey
        )
        PHTVModifierRuntimeStateService.setPendingUppercasePrimeCheckValue(transition.pending)

        guard transition.shouldAttemptPrime else {
            return false
        }
        return PHTVAccessibilityService.shouldPrimeUppercaseFromAX(
            safeMode: safeMode,
            uppercaseEnabled: uppercaseEnabled != 0,
            uppercaseExcluded: uppercaseExcluded != 0
        )
    }

    @objc(hasOtherControlKeyWithFlags:)
    class func hasOtherControlKey(withFlags flags: UInt64) -> Bool {
        let eventFlags = CGEventFlags(rawValue: flags)
        return eventFlags.contains(.maskCommand) ||
               eventFlags.contains(.maskControl) ||
               eventFlags.contains(.maskAlternate) ||
               eventFlags.contains(.maskSecondaryFn) ||
               eventFlags.contains(.maskNumericPad) ||
               eventFlags.contains(.maskHelp)
    }

    @objc(applyDoNothingSyncStateTransitionForCodeTable:extCode:containsUnicodeCompound:)
    class func applyDoNothingSyncStateTransition(forCodeTable codeTable: Int32,
                                                 extCode: Int32,
                                                 containsUnicodeCompound: Bool) -> Bool {
        let hasSyncKey = !PHTVTypingSyncStateService.syncKeyIsEmpty()
        let syncKeyBackValue = hasSyncKey ? PHTVTypingSyncStateService.syncKeyBackValue() : 0
        let syncKeyAction = PHTVInputStrategyService.syncKeyAction(
            forCodeTable: codeTable,
            extCode: extCode,
            hasSyncKey: hasSyncKey,
            syncKeyBackValue: syncKeyBackValue,
            containsUnicodeCompound: containsUnicodeCompound
        )

        guard let action = PHTVSyncKeyAction(rawValue: syncKeyAction) else {
            return false
        }

        switch action {
        case .none:
            return false
        case .clear:
            PHTVTypingSyncStateService.clearSyncKey()
            return false
        case .popAndSendBackspace:
            PHTVTypingSyncStateService.popSyncKeyIfAny()
            return true
        case .pop:
            PHTVTypingSyncStateService.popSyncKeyIfAny()
            return false
        case .insertOne:
            PHTVTypingSyncStateService.appendSyncKeyLength(1)
            return false
        }
    }
}

@objcMembers
final class PHTVEventRuntimeContextService: NSObject {
    nonisolated(unsafe) private static var effectiveTargetBundleId: String?
    nonisolated(unsafe) private static var appCharacteristics: PHTVAppCharacteristicsBox?
    nonisolated(unsafe) private static var postToHIDTap = false
    nonisolated(unsafe) private static var postToSessionForCli = false
    nonisolated(unsafe) private static var cliTarget = false
    nonisolated(unsafe) private static var keyboardType: Int64 = 0
    nonisolated(unsafe) private static var pendingBackspaceCount: Int32 = 0
    nonisolated(unsafe) private static var eventTapProxyRaw: UInt64 = 0

    @objc(configureFromTargetContext:appCharacteristics:keyboardType:)
    class func configure(from targetContext: PHTVEventTargetContextBox,
                         appCharacteristics contextCharacteristics: PHTVAppCharacteristicsBox,
                         keyboardType eventKeyboardType: Int64) {
        effectiveTargetBundleId = targetContext.effectiveBundleId
        appCharacteristics = contextCharacteristics
        postToHIDTap = targetContext.postToHIDTap
        cliTarget = targetContext.isCliTarget
        postToSessionForCli = cliTarget
        keyboardType = eventKeyboardType
        pendingBackspaceCount = 0
    }

    @objc class func clearCliPostFlags() {
        postToSessionForCli = false
        cliTarget = false
    }

    @objc class func appIsSpotlightLike() -> Bool {
        appCharacteristics?.isSpotlightLike ?? false
    }

    @objc class func appNeedsPrecomposedBatched() -> Bool {
        appCharacteristics?.needsPrecomposedBatched ?? false
    }

    @objc class func appNeedsStepByStep() -> Bool {
        appCharacteristics?.needsStepByStep ?? false
    }

    @objc class func appContainsUnicodeCompound() -> Bool {
        appCharacteristics?.containsUnicodeCompound ?? false
    }

    @objc class func postToHIDTapEnabled() -> Bool {
        postToHIDTap
    }

    @objc class func postToSessionForCliEnabled() -> Bool {
        postToSessionForCli
    }

    @objc class func isCliTargetEnabled() -> Bool {
        cliTarget
    }

    @objc class func effectiveTargetBundleIdValue() -> String? {
        effectiveTargetBundleId
    }

    @objc class func currentKeyboardTypeValue() -> Int64 {
        keyboardType
    }

    @objc(setPendingBackspaceCount:)
    class func setPendingBackspaceCount(_ count: Int32) {
        pendingBackspaceCount = max(0, count)
    }

    @objc class func takePendingBackspaceCount() -> Int32 {
        let count = pendingBackspaceCount
        pendingBackspaceCount = 0
        return count
    }

    @objc(setEventTapProxyRawValue:)
    class func setEventTapProxyRawValue(_ value: UInt64) {
        eventTapProxyRaw = value
    }

    @objc class func eventTapProxyRawValue() -> UInt64 {
        eventTapProxyRaw
    }
}

@objcMembers
final class PHTVModifierRuntimeStateService: NSObject {
    nonisolated(unsafe) private static var pendingUppercasePrimeCheck = true
    nonisolated(unsafe) private static var lastFlags: UInt64 = 0
    nonisolated(unsafe) private static var hasJustUsedHotKey = false
    nonisolated(unsafe) private static var pausePressed = false
    nonisolated(unsafe) private static var savedLanguage: Int32 = 1
    nonisolated(unsafe) private static var restoreModifierPressed = false
    nonisolated(unsafe) private static var keyPressedWithRestoreModifier = false
    nonisolated(unsafe) private static var keyPressedWhileSwitchModifiersHeld = false
    nonisolated(unsafe) private static var keyPressedWhileEmojiModifiersHeld = false

    @objc(applySessionResetTransition:)
    class func applySessionResetTransition(_ transition: PHTVSessionResetTransitionBox) {
        pendingUppercasePrimeCheck = transition.pendingUppercasePrimeCheck
        lastFlags = transition.lastFlags
        hasJustUsedHotKey = transition.hasJustUsedHotKey
    }

    @objc class func pendingUppercasePrimeCheckValue() -> Bool {
        pendingUppercasePrimeCheck
    }

    @objc(setPendingUppercasePrimeCheckValue:)
    class func setPendingUppercasePrimeCheckValue(_ value: Bool) {
        pendingUppercasePrimeCheck = value
    }

    @objc class func lastFlagsValue() -> UInt64 {
        lastFlags
    }

    @objc(setLastFlagsValue:)
    class func setLastFlagsValue(_ value: UInt64) {
        lastFlags = value
    }

    @objc class func hasJustUsedHotKeyValue() -> Bool {
        hasJustUsedHotKey
    }

    @objc(setHasJustUsedHotKeyValue:)
    class func setHasJustUsedHotKeyValue(_ value: Bool) {
        hasJustUsedHotKey = value
    }

    @objc class func pausePressedValue() -> Bool {
        pausePressed
    }

    @objc(setPausePressedValue:)
    class func setPausePressedValue(_ value: Bool) {
        pausePressed = value
    }

    @objc class func savedLanguageValue() -> Int32 {
        savedLanguage
    }

    @objc(setSavedLanguageValue:)
    class func setSavedLanguageValue(_ value: Int32) {
        savedLanguage = value
    }

    @objc class func restoreModifierPressedValue() -> Bool {
        restoreModifierPressed
    }

    @objc(setRestoreModifierPressedValue:)
    class func setRestoreModifierPressedValue(_ value: Bool) {
        restoreModifierPressed = value
    }

    @objc class func keyPressedWithRestoreModifierValue() -> Bool {
        keyPressedWithRestoreModifier
    }

    @objc(setKeyPressedWithRestoreModifierValue:)
    class func setKeyPressedWithRestoreModifierValue(_ value: Bool) {
        keyPressedWithRestoreModifier = value
    }

    @objc class func keyPressedWhileSwitchModifiersHeldValue() -> Bool {
        keyPressedWhileSwitchModifiersHeld
    }

    @objc(setKeyPressedWhileSwitchModifiersHeldValue:)
    class func setKeyPressedWhileSwitchModifiersHeldValue(_ value: Bool) {
        keyPressedWhileSwitchModifiersHeld = value
    }

    @objc class func keyPressedWhileEmojiModifiersHeldValue() -> Bool {
        keyPressedWhileEmojiModifiersHeld
    }

    @objc(setKeyPressedWhileEmojiModifiersHeldValue:)
    class func setKeyPressedWhileEmojiModifiersHeldValue(_ value: Bool) {
        keyPressedWhileEmojiModifiersHeld = value
    }
}

@objcMembers
final class PHTVTypingSyncStateService: NSObject {
    nonisolated(unsafe) private static var syncKey: [UInt16] = []

    @objc(setupSyncKeyCapacity:)
    class func setupSyncKeyCapacity(_ capacity: Int32) {
        guard capacity > 0 else {
            return
        }
        syncKey.reserveCapacity(Int(capacity))
    }

    @objc class func clearSyncKey() {
        syncKey.removeAll(keepingCapacity: true)
    }

    @objc(appendSyncKeyLength:)
    class func appendSyncKeyLength(_ length: Int32) {
        guard length > 0 else {
            return
        }
        syncKey.append(UInt16(length))
    }

    @objc class func syncKeyIsEmpty() -> Bool {
        syncKey.isEmpty
    }

    @objc class func syncKeyBackValue() -> Int32 {
        Int32(syncKey.last ?? 0)
    }

    @objc class func popSyncKeyIfAny() {
        guard !syncKey.isEmpty else {
            return
        }
        syncKey.removeLast()
    }

    @objc class func consumeSyncKeyOnBackspace() {
        guard let last = syncKey.last else {
            return
        }
        if last > 1 {
            syncKey[syncKey.count - 1] = last - 1
        } else {
            syncKey.removeLast()
        }
    }
}
