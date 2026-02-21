//
//  PHTVHotkeyService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit
import Carbon

@objc enum PHTVModifierReleaseAction: Int32 {
    case none = 0
    case switchLanguage = 1
    case quickConvert = 2
    case emojiPicker = 3
    case tempOffSpelling = 4
    case tempOffEngine = 5
}

@objc enum PHTVKeyDownHotkeyAction: Int32 {
    case none = 0
    case clearStaleModifiers = 1
    case switchLanguage = 2
    case quickConvert = 3
    case emojiPicker = 4
}

@objc enum PHTVPauseStateAction: Int32 {
    case none = 0
    case activate = 1
    case release = 2
}

@objcMembers
final class PHTVPauseTransitionBox: NSObject {
    let shouldUpdateLanguage: Bool
    let language: Int32
    let pausePressed: Bool
    let savedLanguage: Int32

    init(shouldUpdateLanguage: Bool, language: Int32, pausePressed: Bool, savedLanguage: Int32) {
        self.shouldUpdateLanguage = shouldUpdateLanguage
        self.language = language
        self.pausePressed = pausePressed
        self.savedLanguage = savedLanguage
    }
}

@objcMembers
final class PHTVKeyDownHotkeyEvaluationBox: NSObject {
    let consumeEvent: Bool
    let action: Int32
    let lastFlags: UInt64
    let hasJustUsedHotKey: Bool

    init(consumeEvent: Bool, action: Int32, lastFlags: UInt64, hasJustUsedHotKey: Bool) {
        self.consumeEvent = consumeEvent
        self.action = action
        self.lastFlags = lastFlags
        self.hasJustUsedHotKey = hasJustUsedHotKey
    }
}

@objcMembers
final class PHTVUppercasePrimeTransitionBox: NSObject {
    let shouldAttemptPrime: Bool
    let pending: Bool

    init(shouldAttemptPrime: Bool, pending: Bool) {
        self.shouldAttemptPrime = shouldAttemptPrime
        self.pending = pending
    }
}

@objcMembers
final class PHTVModifierPressTransitionBox: NSObject {
    let lastFlags: UInt64
    let keyPressedWithRestoreModifier: Bool
    let restoreModifierPressed: Bool
    let keyPressedWhileSwitchModifiersHeld: Bool
    let keyPressedWhileEmojiModifiersHeld: Bool
    let shouldUpdateLanguage: Bool
    let language: Int32
    let pausePressed: Bool
    let savedLanguage: Int32

    init(
        lastFlags: UInt64,
        keyPressedWithRestoreModifier: Bool,
        restoreModifierPressed: Bool,
        keyPressedWhileSwitchModifiersHeld: Bool,
        keyPressedWhileEmojiModifiersHeld: Bool,
        shouldUpdateLanguage: Bool,
        language: Int32,
        pausePressed: Bool,
        savedLanguage: Int32
    ) {
        self.lastFlags = lastFlags
        self.keyPressedWithRestoreModifier = keyPressedWithRestoreModifier
        self.restoreModifierPressed = restoreModifierPressed
        self.keyPressedWhileSwitchModifiersHeld = keyPressedWhileSwitchModifiersHeld
        self.keyPressedWhileEmojiModifiersHeld = keyPressedWhileEmojiModifiersHeld
        self.shouldUpdateLanguage = shouldUpdateLanguage
        self.language = language
        self.pausePressed = pausePressed
        self.savedLanguage = savedLanguage
    }
}

@objcMembers
final class PHTVKeyDownModifierTrackingBox: NSObject {
    let keyPressedWithRestoreModifier: Bool
    let keyPressedWhileSwitchModifiersHeld: Bool
    let keyPressedWhileEmojiModifiersHeld: Bool

    init(
        keyPressedWithRestoreModifier: Bool,
        keyPressedWhileSwitchModifiersHeld: Bool,
        keyPressedWhileEmojiModifiersHeld: Bool
    ) {
        self.keyPressedWithRestoreModifier = keyPressedWithRestoreModifier
        self.keyPressedWhileSwitchModifiersHeld = keyPressedWhileSwitchModifiersHeld
        self.keyPressedWhileEmojiModifiersHeld = keyPressedWhileEmojiModifiersHeld
    }
}

@objcMembers
final class PHTVModifierReleaseTransitionBox: NSObject {
    let shouldAttemptRestore: Bool
    let shouldResetRestoreState: Bool
    let releaseAction: Int32
    let shouldUpdateLanguage: Bool
    let language: Int32
    let pausePressed: Bool
    let savedLanguage: Int32
    let lastFlags: UInt64
    let keyPressedWhileSwitchModifiersHeld: Bool
    let keyPressedWhileEmojiModifiersHeld: Bool

    init(
        shouldAttemptRestore: Bool,
        shouldResetRestoreState: Bool,
        releaseAction: Int32,
        shouldUpdateLanguage: Bool,
        language: Int32,
        pausePressed: Bool,
        savedLanguage: Int32,
        lastFlags: UInt64,
        keyPressedWhileSwitchModifiersHeld: Bool,
        keyPressedWhileEmojiModifiersHeld: Bool
    ) {
        self.shouldAttemptRestore = shouldAttemptRestore
        self.shouldResetRestoreState = shouldResetRestoreState
        self.releaseAction = releaseAction
        self.shouldUpdateLanguage = shouldUpdateLanguage
        self.language = language
        self.pausePressed = pausePressed
        self.savedLanguage = savedLanguage
        self.lastFlags = lastFlags
        self.keyPressedWhileSwitchModifiersHeld = keyPressedWhileSwitchModifiersHeld
        self.keyPressedWhileEmojiModifiersHeld = keyPressedWhileEmojiModifiersHeld
    }
}

@objcMembers
final class PHTVSessionResetTransitionBox: NSObject {
    let shouldClearSyncKey: Bool
    let shouldPrimeUppercaseFirstChar: Bool
    let pendingUppercasePrimeCheck: Bool
    let lastFlags: UInt64
    let willContinueSending: Bool
    let willSendControlKey: Bool
    let hasJustUsedHotKey: Bool

    init(
        shouldClearSyncKey: Bool,
        shouldPrimeUppercaseFirstChar: Bool,
        pendingUppercasePrimeCheck: Bool,
        lastFlags: UInt64,
        willContinueSending: Bool,
        willSendControlKey: Bool,
        hasJustUsedHotKey: Bool
    ) {
        self.shouldClearSyncKey = shouldClearSyncKey
        self.shouldPrimeUppercaseFirstChar = shouldPrimeUppercaseFirstChar
        self.pendingUppercasePrimeCheck = pendingUppercasePrimeCheck
        self.lastFlags = lastFlags
        self.willContinueSending = willContinueSending
        self.willSendControlKey = willSendControlKey
        self.hasJustUsedHotKey = hasJustUsedHotKey
    }
}

@objcMembers
final class PHTVHotkeyService: NSObject {
    private static let hotkeyKeyMask: UInt32 = 0x00FF
    private static let hotkeyControlMask: UInt32 = 0x0100
    private static let hotkeyOptionMask: UInt32 = 0x0200
    private static let hotkeyCommandMask: UInt32 = 0x0400
    private static let hotkeyShiftMask: UInt32 = 0x0800
    private static let hotkeyFnMask: UInt32 = 0x1000
    private static let hotkeyBeepMask: UInt32 = 0x8000
    private static let hotkeyNoKey: UInt32 = 0x00FE
    private static let emptyHotkey: UInt32 = 0xFE0000FE

    private static let controlFlagMask = CGEventFlags.maskControl.rawValue
    private static let optionFlagMask = CGEventFlags.maskAlternate.rawValue
    private static let commandFlagMask = CGEventFlags.maskCommand.rawValue
    private static let shiftFlagMask = CGEventFlags.maskShift.rawValue
    private static let fnFlagMask = CGEventFlags.maskSecondaryFn.rawValue
    private static let layoutCacheNoValue: UInt16 = .max
    private static let relevantModifierFlagsMask = commandFlagMask
        | optionFlagMask
        | controlFlagMask
        | shiftFlagMask
        | fnFlagMask

    // Reverse mapping from layout character -> US keycode
    private static let layoutKeyStringToKeyCodeMap: [String: UInt16] = [
        // Number row
        "`": 50, "~": 50, "1": 18, "!": 18, "2": 19, "@": 19, "3": 20, "#": 20, "4": 21, "$": 21,
        "5": 23, "%": 23, "6": 22, "^": 22, "7": 26, "&": 26, "8": 28, "*": 28, "9": 25, "(": 25,
        "0": 29, ")": 29, "-": 27, "_": 27, "=": 24, "+": 24,
        // First row (QWERTY)
        "q": 12, "w": 13, "e": 14, "r": 15, "t": 17, "y": 16, "u": 32, "i": 34, "o": 31, "p": 35,
        "[": 33, "{": 33, "]": 30, "}": 30, "\\": 42, "|": 42,
        // Second row (home row)
        "a": 0, "s": 1, "d": 2, "f": 3, "g": 5, "h": 4, "j": 38, "k": 40, "l": 37,
        ";": 41, ":": 41, "'": 39, "\"": 39,
        // Third row
        "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "n": 45, "m": 46,
        ",": 43, "<": 43, ".": 47, ">": 47, "/": 44, "?": 44,

        // International layout characters
        "ß": 27, "ü": 33, "ö": 41, "ä": 39, "é": 19, "è": 26, "ù": 39, "²": 50,
        "«": 30, "»": 42, "µ": 42, "ñ": 41, "¡": 24, "¿": 27, "¬": 50, "ò": 41,
        "ì": 24, "ç": 41, "º": 50, "ª": 50, "å": 33, "æ": 39, "ø": 41, "§": 50,
        "½": 50, "¤": 21, "ą": 0, "ć": 8, "ę": 14, "ł": 37, "ń": 45, "ó": 31, "ś": 1,
        "ź": 7, "ż": 6, "ě": 19, "š": 20, "č": 21, "ř": 23, "ž": 22, "ý": 26, "á": 28,
        "í": 25, "ú": 41, "ů": 33, "ď": 30, "ť": 39, "ň": 42, "ő": 27, "ű": 42,
        "ğ": 33, "ş": 41, "ı": 34, "´": 24, "¨": 33, "à": 29, "€": 14, "£": 20,
        "¥": 16, "¢": 8, "©": 8, "®": 15, "™": 17, "°": 28, "±": 24, "×": 7,
        "÷": 44, "≠": 24, "≤": 43, "≥": 47, "∞": 23, "…": 41, "–": 27, "—": 27,
        "‘": 39, "’": 39, "“": 39, "”": 39
    ]

    private static let azertyShiftedToNumber: [String: UInt16] = [
        "&": 18,
        "é": 19,
        "\"": 20,
        "'": 21,
        "(": 23,
        "-": 22,
        "è": 26,
        "_": 28,
        "ç": 25,
        "à": 29
    ]

    private class func hasMask(_ data: UInt32, mask: UInt32) -> Bool {
        (data & mask) != 0
    }

    private class func flagSet(_ flags: UInt64, mask: UInt64) -> Bool {
        (flags & mask) != 0
    }

    private class func isEmptyHotkey(_ data: UInt32) -> Bool {
        (data & ~hotkeyBeepMask) == emptyHotkey
    }

    private class func hasHotkeyKey(_ data: UInt32) -> Bool {
        (data & hotkeyKeyMask) != hotkeyNoKey
    }

    private class func keyMatches(_ data: UInt32, currentKeycode: UInt16) -> Bool {
        (data & hotkeyKeyMask) == UInt32(currentKeycode & UInt16(hotkeyKeyMask))
    }

    private class func matchesFlags(_ data: UInt32, currentFlags: UInt64) -> Bool {
        if hasMask(data, mask: hotkeyControlMask) != flagSet(currentFlags, mask: controlFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyOptionMask) != flagSet(currentFlags, mask: optionFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyCommandMask) != flagSet(currentFlags, mask: commandFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyShiftMask) != flagSet(currentFlags, mask: shiftFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyFnMask) != flagSet(currentFlags, mask: fnFlagMask) {
            return false
        }
        return true
    }

    private class func modifiersHeld(_ data: UInt32, currentFlags: UInt64) -> Bool {
        if hasMask(data, mask: hotkeyControlMask) && !flagSet(currentFlags, mask: controlFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyOptionMask) && !flagSet(currentFlags, mask: optionFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyCommandMask) && !flagSet(currentFlags, mask: commandFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyShiftMask) && !flagSet(currentFlags, mask: shiftFlagMask) {
            return false
        }
        if hasMask(data, mask: hotkeyFnMask) && !flagSet(currentFlags, mask: fnFlagMask) {
            return false
        }
        return true
    }

    @objc(checkHotKey:checkKeyCode:currentKeycode:currentFlags:)
    class func checkHotKey(
        _ hotKeyData: Int32,
        checkKeyCode: Bool,
        currentKeycode: UInt16,
        currentFlags: UInt64
    ) -> Bool {
        let data = UInt32(bitPattern: hotKeyData)
        if isEmptyHotkey(data) {
            return false
        }
        if !matchesFlags(data, currentFlags: currentFlags) {
            return false
        }
        if checkKeyCode && !keyMatches(data, currentKeycode: currentKeycode) {
            return false
        }
        return true
    }

    @objc(hotkeyModifiersAreHeld:currentFlags:)
    class func hotkeyModifiersAreHeld(_ hotKeyData: Int32, currentFlags: UInt64) -> Bool {
        let data = UInt32(bitPattern: hotKeyData)
        if isEmptyHotkey(data) {
            return false
        }
        return modifiersHeld(data, currentFlags: currentFlags)
    }

    @objc(isModifierOnlyHotkey:)
    class func isModifierOnlyHotkey(_ hotKeyData: Int32) -> Bool {
        let data = UInt32(bitPattern: hotKeyData)
        return !hasHotkeyKey(data)
    }

    private class func isOptionRestoreKey(_ customEscapeKey: Int32) -> Bool {
        Int(customEscapeKey) == kVK_Option || Int(customEscapeKey) == kVK_RightOption
    }

    private class func isControlRestoreKey(_ customEscapeKey: Int32) -> Bool {
        Int(customEscapeKey) == kVK_Control || Int(customEscapeKey) == kVK_RightControl
    }

    private class func isRestoreModifierReleased(
        customEscapeKey: Int32,
        oldFlags: UInt64,
        newFlags: UInt64
    ) -> Bool {
        let optionReleased = isOptionRestoreKey(customEscapeKey)
            && (oldFlags & optionFlagMask) != 0
            && (newFlags & optionFlagMask) == 0
        let controlReleased = isControlRestoreKey(customEscapeKey)
            && (oldFlags & controlFlagMask) != 0
            && (newFlags & controlFlagMask) == 0
        return optionReleased || controlReleased
    }

    @objc(shouldEnterRestoreModifierStateWithRestoreOnEscape:customEscapeKey:flags:)
    class func shouldEnterRestoreModifierState(
        restoreOnEscape: Int32,
        customEscapeKey: Int32,
        flags: UInt64
    ) -> Bool {
        guard restoreOnEscape != 0, customEscapeKey > 0 else {
            return false
        }
        if isOptionRestoreKey(customEscapeKey) {
            return (flags & optionFlagMask) != 0
        }
        if isControlRestoreKey(customEscapeKey) {
            return (flags & controlFlagMask) != 0
        }
        return false
    }

    @objc(shouldAttemptRestoreOnModifierReleaseWithRestoreOnEscape:restoreModifierPressed:keyPressedWithRestoreModifier:customEscapeKey:oldFlags:newFlags:)
    class func shouldAttemptRestoreOnModifierRelease(
        restoreOnEscape: Int32,
        restoreModifierPressed: Bool,
        keyPressedWithRestoreModifier: Bool,
        customEscapeKey: Int32,
        oldFlags: UInt64,
        newFlags: UInt64
    ) -> Bool {
        guard restoreOnEscape != 0 else {
            return false
        }
        guard restoreModifierPressed, !keyPressedWithRestoreModifier else {
            return false
        }
        return isRestoreModifierReleased(
            customEscapeKey: customEscapeKey,
            oldFlags: oldFlags,
            newFlags: newFlags
        )
    }

    @objc(shouldResetRestoreModifierStateWithRestoreModifierPressed:customEscapeKey:oldFlags:newFlags:)
    class func shouldResetRestoreModifierState(
        restoreModifierPressed: Bool,
        customEscapeKey: Int32,
        oldFlags: UInt64,
        newFlags: UInt64
    ) -> Bool {
        guard restoreModifierPressed else {
            return false
        }
        return isRestoreModifierReleased(
            customEscapeKey: customEscapeKey,
            oldFlags: oldFlags,
            newFlags: newFlags
        )
    }

    @objc(shouldMarkKeyPressedWithRestoreModifierWithRestoreOnEscape:customEscapeKey:restoreModifierPressed:)
    class func shouldMarkKeyPressedWithRestoreModifier(
        restoreOnEscape: Int32,
        customEscapeKey: Int32,
        restoreModifierPressed: Bool
    ) -> Bool {
        restoreOnEscape != 0 && customEscapeKey > 0 && restoreModifierPressed
    }

    @objc(relevantHotkeyModifierFlags:)
    class func relevantHotkeyModifierFlags(_ flags: UInt64) -> UInt64 {
        flags & relevantModifierFlagsMask
    }

    @objc(isEmojiModifierOnlyHotkeyForKeyCode:)
    class func isEmojiModifierOnlyHotkey(forKeyCode emojiHotkeyKeyCode: Int32) -> Bool {
        let key = UInt32(bitPattern: emojiHotkeyKeyCode) & hotkeyKeyMask
        return key == hotkeyNoKey
    }

    @objc(emojiHotkeyModifiersAreHeld:emojiModifiers:)
    class func emojiHotkeyModifiersAreHeld(_ currentFlags: UInt64, emojiModifiers: Int32) -> Bool {
        let expected = relevantHotkeyModifierFlags(UInt64(UInt32(bitPattern: emojiModifiers)))
        if expected == 0 {
            return false
        }
        let current = relevantHotkeyModifierFlags(currentFlags)
        return (current & expected) == expected
    }

    @objc(checkEmojiHotkeyEnabled:keycode:flags:emojiModifiers:emojiHotkeyKeyCode:)
    class func checkEmojiHotkey(
        enabled: Int32,
        keycode: UInt16,
        flags: UInt64,
        emojiModifiers: Int32,
        emojiHotkeyKeyCode: Int32
    ) -> Bool {
        if enabled == 0 {
            return false
        }
        if isEmojiModifierOnlyHotkey(forKeyCode: emojiHotkeyKeyCode) {
            return false
        }

        let expectedKeycode = UInt16(truncatingIfNeeded: emojiHotkeyKeyCode)
        if expectedKeycode != keycode {
            return false
        }

        let expectedModifiers = relevantHotkeyModifierFlags(UInt64(UInt32(bitPattern: emojiModifiers)))
        if expectedModifiers == 0 {
            return false
        }

        return relevantHotkeyModifierFlags(flags) == expectedModifiers
    }

    @objc(evaluateKeyDownHotkeyActionForKeyCode:lastFlags:currentFlags:switchHotkey:convertHotkey:emojiEnabled:emojiModifiers:emojiHotkeyKeyCode:)
    class func evaluateKeyDownHotkeyAction(
        forKeyCode keyCode: UInt16,
        lastFlags: UInt64,
        currentFlags: UInt64,
        switchHotkey: Int32,
        convertHotkey: Int32,
        emojiEnabled: Int32,
        emojiModifiers: Int32,
        emojiHotkeyKeyCode: Int32
    ) -> Int32 {
        let switchData = UInt32(bitPattern: switchHotkey)
        let convertData = UInt32(bitPattern: convertHotkey)

        let switchHasKey = hasHotkeyKey(switchData)
        let convertHasKey = hasHotkeyKey(convertData)

        let isSwitchHotkeyKey = switchHasKey && keyMatches(switchData, currentKeycode: keyCode)
        let isConvertHotkeyKey = convertHasKey && keyMatches(convertData, currentKeycode: keyCode)
        let isEmojiHotkeyKey = emojiEnabled != 0
            && UInt16(truncatingIfNeeded: emojiHotkeyKeyCode) == keyCode

        if !isSwitchHotkeyKey && !isConvertHotkeyKey && !isEmojiHotkeyKey {
            return PHTVKeyDownHotkeyAction.clearStaleModifiers.rawValue
        }

        if isSwitchHotkeyKey {
            let matchedOnLastFlags = checkHotKey(
                switchHotkey,
                checkKeyCode: true,
                currentKeycode: keyCode,
                currentFlags: lastFlags
            )
            let matchedOnCurrentFlags = checkHotKey(
                switchHotkey,
                checkKeyCode: true,
                currentKeycode: keyCode,
                currentFlags: currentFlags
            )
            if matchedOnLastFlags || matchedOnCurrentFlags {
                return PHTVKeyDownHotkeyAction.switchLanguage.rawValue
            }
        }

        if isConvertHotkeyKey {
            let matchedOnLastFlags = checkHotKey(
                convertHotkey,
                checkKeyCode: true,
                currentKeycode: keyCode,
                currentFlags: lastFlags
            )
            let matchedOnCurrentFlags = checkHotKey(
                convertHotkey,
                checkKeyCode: true,
                currentKeycode: keyCode,
                currentFlags: currentFlags
            )
            if matchedOnLastFlags || matchedOnCurrentFlags {
                return PHTVKeyDownHotkeyAction.quickConvert.rawValue
            }
        }

        if isEmojiHotkeyKey && checkEmojiHotkey(
            enabled: emojiEnabled,
            keycode: keyCode,
            flags: currentFlags,
            emojiModifiers: emojiModifiers,
            emojiHotkeyKeyCode: emojiHotkeyKeyCode
        ) {
            return PHTVKeyDownHotkeyAction.emojiPicker.rawValue
        }

        return PHTVKeyDownHotkeyAction.none.rawValue
    }

    @objc(processKeyDownHotkeyWithKeyCode:lastFlags:currentFlags:switchHotkey:convertHotkey:emojiEnabled:emojiModifiers:emojiHotkeyKeyCode:)
    class func processKeyDownHotkey(
        withKeyCode keyCode: UInt16,
        lastFlags: UInt64,
        currentFlags: UInt64,
        switchHotkey: Int32,
        convertHotkey: Int32,
        emojiEnabled: Int32,
        emojiModifiers: Int32,
        emojiHotkeyKeyCode: Int32
    ) -> PHTVKeyDownHotkeyEvaluationBox {
        let action = evaluateKeyDownHotkeyAction(
            forKeyCode: keyCode,
            lastFlags: lastFlags,
            currentFlags: currentFlags,
            switchHotkey: switchHotkey,
            convertHotkey: convertHotkey,
            emojiEnabled: emojiEnabled,
            emojiModifiers: emojiModifiers,
            emojiHotkeyKeyCode: emojiHotkeyKeyCode
        )

        if action == PHTVKeyDownHotkeyAction.clearStaleModifiers.rawValue {
            return PHTVKeyDownHotkeyEvaluationBox(
                consumeEvent: false,
                action: PHTVKeyDownHotkeyAction.none.rawValue,
                lastFlags: 0,
                hasJustUsedHotKey: false
            )
        }

        return PHTVKeyDownHotkeyEvaluationBox(
            consumeEvent: false,
            action: action,
            lastFlags: lastFlags,
            hasJustUsedHotKey: lastFlags != 0
        )
    }

    @objc(shouldMarkSwitchModifiersHeldForFlags:switchHotkey:convertHotkey:)
    class func shouldMarkSwitchModifiersHeld(
        forFlags flags: UInt64,
        switchHotkey: Int32,
        convertHotkey: Int32
    ) -> Bool {
        let switchIsModifierOnly = isModifierOnlyHotkey(switchHotkey)
        let convertIsModifierOnly = isModifierOnlyHotkey(convertHotkey)
        if !switchIsModifierOnly && !convertIsModifierOnly {
            return false
        }

        let switchModifiersHeld = switchIsModifierOnly
            && hotkeyModifiersAreHeld(switchHotkey, currentFlags: flags)
        let convertModifiersHeld = convertIsModifierOnly
            && hotkeyModifiersAreHeld(convertHotkey, currentFlags: flags)
        return switchModifiersHeld || convertModifiersHeld
    }

    @objc(shouldMarkEmojiModifiersHeldForFlags:emojiEnabled:emojiModifiers:emojiHotkeyKeyCode:)
    class func shouldMarkEmojiModifiersHeld(
        forFlags flags: UInt64,
        emojiEnabled: Int32,
        emojiModifiers: Int32,
        emojiHotkeyKeyCode: Int32
    ) -> Bool {
        guard emojiEnabled != 0 else {
            return false
        }
        guard isEmojiModifierOnlyHotkey(forKeyCode: emojiHotkeyKeyCode) else {
            return false
        }
        return emojiHotkeyModifiersAreHeld(flags, emojiModifiers: emojiModifiers)
    }

    @objc(evaluateModifierReleaseActionWithLastFlags:switchHotkey:convertHotkey:emojiEnabled:emojiModifiers:emojiKeyCode:keyPressedWhileSwitchModifiersHeld:keyPressedWhileEmojiModifiersHeld:hasJustUsedHotkey:tempOffSpellingEnabled:tempOffEngineEnabled:)
    class func evaluateModifierReleaseAction(
        lastFlags: UInt64,
        switchHotkey: Int32,
        convertHotkey: Int32,
        emojiEnabled: Int32,
        emojiModifiers: Int32,
        emojiKeyCode: Int32,
        keyPressedWhileSwitchModifiersHeld: Bool,
        keyPressedWhileEmojiModifiersHeld: Bool,
        hasJustUsedHotkey: Bool,
        tempOffSpellingEnabled: Int32,
        tempOffEngineEnabled: Int32
    ) -> Int32 {
        let switchHasKey = hasHotkeyKey(UInt32(bitPattern: switchHotkey))
        let switchIsModifierOnly = isModifierOnlyHotkey(switchHotkey)
        let canTriggerSwitch = !switchIsModifierOnly || !keyPressedWhileSwitchModifiersHeld
        let switchMatched = checkHotKey(
            switchHotkey,
            checkKeyCode: switchHasKey,
            currentKeycode: 0,
            currentFlags: lastFlags
        )
        if canTriggerSwitch && switchMatched {
            return PHTVModifierReleaseAction.switchLanguage.rawValue
        }

        let convertHasKey = hasHotkeyKey(UInt32(bitPattern: convertHotkey))
        let convertIsModifierOnly = isModifierOnlyHotkey(convertHotkey)
        let canTriggerConvert = !convertIsModifierOnly || !keyPressedWhileSwitchModifiersHeld
        let convertMatched = checkHotKey(
            convertHotkey,
            checkKeyCode: convertHasKey,
            currentKeycode: 0,
            currentFlags: lastFlags
        )
        if canTriggerConvert && convertMatched {
            return PHTVModifierReleaseAction.quickConvert.rawValue
        }

        if emojiEnabled != 0 &&
            isEmojiModifierOnlyHotkey(forKeyCode: emojiKeyCode) &&
            !keyPressedWhileEmojiModifiersHeld {
            let expectedEmoji = relevantHotkeyModifierFlags(UInt64(UInt32(bitPattern: emojiModifiers)))
            let lastEmoji = relevantHotkeyModifierFlags(lastFlags)
            if expectedEmoji != 0 && lastEmoji == expectedEmoji {
                return PHTVModifierReleaseAction.emojiPicker.rawValue
            }
        }

        if tempOffSpellingEnabled != 0 &&
            !hasJustUsedHotkey &&
            (lastFlags & controlFlagMask) != 0 {
            return PHTVModifierReleaseAction.tempOffSpelling.rawValue
        }

        if tempOffEngineEnabled != 0 &&
            !hasJustUsedHotkey &&
            (lastFlags & commandFlagMask) != 0 {
            return PHTVModifierReleaseAction.tempOffEngine.rawValue
        }

        return PHTVModifierReleaseAction.none.rawValue
    }

    // Packed release plan format:
    // - bit 0: should attempt restore-to-raw-keys
    // - bit 1: should reset restore-modifier state
    // - bits 8...15: PHTVModifierReleaseAction value
    @objc(evaluateFlagsReleasePlanWithRestoreOnEscape:restoreModifierPressed:keyPressedWithRestoreModifier:customEscapeKey:oldFlags:newFlags:switchHotkey:convertHotkey:emojiEnabled:emojiModifiers:emojiKeyCode:keyPressedWhileSwitchModifiersHeld:keyPressedWhileEmojiModifiersHeld:hasJustUsedHotkey:tempOffSpellingEnabled:tempOffEngineEnabled:)
    class func evaluateFlagsReleasePlan(
        restoreOnEscape: Int32,
        restoreModifierPressed: Bool,
        keyPressedWithRestoreModifier: Bool,
        customEscapeKey: Int32,
        oldFlags: UInt64,
        newFlags: UInt64,
        switchHotkey: Int32,
        convertHotkey: Int32,
        emojiEnabled: Int32,
        emojiModifiers: Int32,
        emojiKeyCode: Int32,
        keyPressedWhileSwitchModifiersHeld: Bool,
        keyPressedWhileEmojiModifiersHeld: Bool,
        hasJustUsedHotkey: Bool,
        tempOffSpellingEnabled: Int32,
        tempOffEngineEnabled: Int32
    ) -> Int32 {
        let shouldAttemptRestore = shouldAttemptRestoreOnModifierRelease(
            restoreOnEscape: restoreOnEscape,
            restoreModifierPressed: restoreModifierPressed,
            keyPressedWithRestoreModifier: keyPressedWithRestoreModifier,
            customEscapeKey: customEscapeKey,
            oldFlags: oldFlags,
            newFlags: newFlags
        )

        let shouldResetRestore = shouldResetRestoreModifierState(
            restoreModifierPressed: restoreModifierPressed,
            customEscapeKey: customEscapeKey,
            oldFlags: oldFlags,
            newFlags: newFlags
        )

        let releaseAction = evaluateModifierReleaseAction(
            lastFlags: oldFlags,
            switchHotkey: switchHotkey,
            convertHotkey: convertHotkey,
            emojiEnabled: emojiEnabled,
            emojiModifiers: emojiModifiers,
            emojiKeyCode: emojiKeyCode,
            keyPressedWhileSwitchModifiersHeld: keyPressedWhileSwitchModifiersHeld,
            keyPressedWhileEmojiModifiersHeld: keyPressedWhileEmojiModifiersHeld,
            hasJustUsedHotkey: hasJustUsedHotkey,
            tempOffSpellingEnabled: tempOffSpellingEnabled,
            tempOffEngineEnabled: tempOffEngineEnabled
        )

        var plan: Int32 = 0
        if shouldAttemptRestore {
            plan |= 1
        }
        if shouldResetRestore {
            plan |= 1 << 1
        }
        plan |= (releaseAction & 0xFF) << 8
        return plan
    }

    @objc(flagsReleasePlanShouldAttemptRestore:)
    class func flagsReleasePlanShouldAttemptRestore(_ plan: Int32) -> Bool {
        (plan & 1) != 0
    }

    @objc(flagsReleasePlanShouldResetRestoreState:)
    class func flagsReleasePlanShouldResetRestoreState(_ plan: Int32) -> Bool {
        (plan & (1 << 1)) != 0
    }

    @objc(flagsReleasePlanModifierReleaseAction:)
    class func flagsReleasePlanModifierReleaseAction(_ plan: Int32) -> Int32 {
        (plan >> 8) & 0xFF
    }

    @objc(evaluatePauseStateActionWithOldFlags:newFlags:pauseKeyEnabled:pauseKeyCode:pausePressed:)
    class func evaluatePauseStateAction(
        oldFlags: UInt64,
        newFlags: UInt64,
        pauseKeyEnabled: Int32,
        pauseKeyCode: Int32,
        pausePressed: Bool
    ) -> Int32 {
        guard pauseKeyEnabled != 0, pauseKeyCode > 0 else {
            return PHTVPauseStateAction.none.rawValue
        }

        if !pausePressed {
            if shouldActivatePauseMode(withFlags: newFlags, pauseKeyCode: pauseKeyCode) {
                return PHTVPauseStateAction.activate.rawValue
            }
            return PHTVPauseStateAction.none.rawValue
        }

        if shouldReleasePauseMode(fromOldFlags: oldFlags, newFlags: newFlags, pauseKeyCode: pauseKeyCode) {
            return PHTVPauseStateAction.release.rawValue
        }

        return PHTVPauseStateAction.none.rawValue
    }

    @objc(shouldStripPauseModifierWithFlags:pauseKeyCode:)
    class func shouldStripPauseModifier(withFlags flags: UInt64, pauseKeyCode: Int32) -> Bool {
        var otherModifiers = flags & ~CGEventFlags.maskNonCoalesced.rawValue

        let pauseMask = pauseModifierMask(forKeyCode: pauseKeyCode)
        if pauseMask != 0 {
            otherModifiers &= ~pauseMask
        }

        let significantModifiers = commandFlagMask | controlFlagMask | optionFlagMask | shiftFlagMask
        return (otherModifiers & significantModifiers) == 0
    }

    @objc(pauseModifierMaskForKeyCode:)
    class func pauseModifierMask(forKeyCode keyCode: Int32) -> UInt64 {
        switch Int(keyCode) {
        case kVK_Option, kVK_RightOption:
            return optionFlagMask
        case kVK_Control, kVK_RightControl:
            return controlFlagMask
        case kVK_Shift, kVK_RightShift:
            return shiftFlagMask
        case kVK_Command, kVK_RightCommand:
            return commandFlagMask
        case kVK_Function:
            return fnFlagMask
        default:
            return 0
        }
    }

    @objc(stripPauseModifierForFlags:pauseKeyCode:)
    class func stripPauseModifier(forFlags flags: UInt64, pauseKeyCode: Int32) -> UInt64 {
        let pauseMask = pauseModifierMask(forKeyCode: pauseKeyCode)
        if pauseMask == 0 {
            return flags
        }
        return flags & ~pauseMask
    }

    @objc(shouldActivatePauseModeWithFlags:pauseKeyCode:)
    class func shouldActivatePauseMode(withFlags flags: UInt64, pauseKeyCode: Int32) -> Bool {
        let pauseMask = pauseModifierMask(forKeyCode: pauseKeyCode)
        return pauseMask != 0 && (flags & pauseMask) != 0
    }

    @objc(isUppercasePrimeCandidateWithCharacter:flags:)
    class func isUppercasePrimeCandidate(character: UInt16, flags: UInt64) -> Bool {
        let blockedModifierMask = commandFlagMask
            | controlFlagMask
            | optionFlagMask
            | fnFlagMask
            | CGEventFlags.maskNumericPad.rawValue
            | CGEventFlags.maskHelp.rawValue

        if (flags & blockedModifierMask) != 0 {
            return false
        }

        if character == 0 {
            return false
        }

        switch UnicodeScalar(Int(character)) {
        case " ", "\t", "\n", "\r":
            return false
        default:
            return true
        }
    }

    @objc(uppercasePrimeTransitionForPending:flags:keyCode:keyCharacter:isNavigationKey:)
    class func uppercasePrimeTransition(
        forPending pending: Bool,
        flags: UInt64,
        keyCode: UInt16,
        keyCharacter: UInt16,
        isNavigationKey: Bool
    ) -> PHTVUppercasePrimeTransitionBox {
        let focusModifierMask = commandFlagMask
            | controlFlagMask
            | optionFlagMask
            | fnFlagMask
            | CGEventFlags.maskNumericPad.rawValue
            | CGEventFlags.maskHelp.rawValue

        var nextPending = pending
        let hasFocusModifiers = (flags & focusModifierMask) != 0
        if hasFocusModifiers || keyCode == UInt16(kVK_Tab) || isNavigationKey {
            nextPending = true
        }

        let shouldAttemptPrime = nextPending
            && isUppercasePrimeCandidate(character: keyCharacter, flags: flags)

        if shouldAttemptPrime {
            nextPending = false
        }

        return PHTVUppercasePrimeTransitionBox(
            shouldAttemptPrime: shouldAttemptPrime,
            pending: nextPending
        )
    }

    @objc(keyDownModifierTrackingForFlags:restoreOnEscape:customEscapeKey:restoreModifierPressed:keyPressedWithRestoreModifier:switchHotkey:convertHotkey:keyPressedWhileSwitchModifiersHeld:emojiEnabled:emojiModifiers:emojiHotkeyKeyCode:keyPressedWhileEmojiModifiersHeld:)
    class func keyDownModifierTracking(
        forFlags flags: UInt64,
        restoreOnEscape: Int32,
        customEscapeKey: Int32,
        restoreModifierPressed: Bool,
        keyPressedWithRestoreModifier: Bool,
        switchHotkey: Int32,
        convertHotkey: Int32,
        keyPressedWhileSwitchModifiersHeld: Bool,
        emojiEnabled: Int32,
        emojiModifiers: Int32,
        emojiHotkeyKeyCode: Int32,
        keyPressedWhileEmojiModifiersHeld: Bool
    ) -> PHTVKeyDownModifierTrackingBox {
        var nextKeyPressedWithRestoreModifier = keyPressedWithRestoreModifier
        if shouldMarkKeyPressedWithRestoreModifier(
            restoreOnEscape: restoreOnEscape,
            customEscapeKey: customEscapeKey,
            restoreModifierPressed: restoreModifierPressed
        ) {
            nextKeyPressedWithRestoreModifier = true
        }

        var nextKeyPressedWhileSwitchModifiersHeld = keyPressedWhileSwitchModifiersHeld
        if shouldMarkSwitchModifiersHeld(
            forFlags: flags,
            switchHotkey: switchHotkey,
            convertHotkey: convertHotkey
        ) {
            nextKeyPressedWhileSwitchModifiersHeld = true
        }

        var nextKeyPressedWhileEmojiModifiersHeld = keyPressedWhileEmojiModifiersHeld
        if shouldMarkEmojiModifiersHeld(
            forFlags: flags,
            emojiEnabled: emojiEnabled,
            emojiModifiers: emojiModifiers,
            emojiHotkeyKeyCode: emojiHotkeyKeyCode
        ) {
            nextKeyPressedWhileEmojiModifiersHeld = true
        }

        return PHTVKeyDownModifierTrackingBox(
            keyPressedWithRestoreModifier: nextKeyPressedWithRestoreModifier,
            keyPressedWhileSwitchModifiersHeld: nextKeyPressedWhileSwitchModifiersHeld,
            keyPressedWhileEmojiModifiersHeld: nextKeyPressedWhileEmojiModifiersHeld
        )
    }

    @objc(modifierPressTransitionForFlags:restoreOnEscape:customEscapeKey:keyPressedWithRestoreModifier:restoreModifierPressed:pauseKeyEnabled:pauseKeyCode:pausePressed:currentLanguage:savedLanguage:)
    class func modifierPressTransition(
        forFlags flags: UInt64,
        restoreOnEscape: Int32,
        customEscapeKey: Int32,
        keyPressedWithRestoreModifier: Bool,
        restoreModifierPressed: Bool,
        pauseKeyEnabled: Int32,
        pauseKeyCode: Int32,
        pausePressed: Bool,
        currentLanguage: Int32,
        savedLanguage: Int32
    ) -> PHTVModifierPressTransitionBox {
        var nextKeyPressedWithRestoreModifier = keyPressedWithRestoreModifier
        var nextRestoreModifierPressed = restoreModifierPressed
        if shouldEnterRestoreModifierState(
            restoreOnEscape: restoreOnEscape,
            customEscapeKey: customEscapeKey,
            flags: flags
        ) {
            nextRestoreModifierPressed = true
            nextKeyPressedWithRestoreModifier = false
        }

        let pausePressTransition = pauseTransitionForPress(
            withFlags: flags,
            pauseKeyEnabled: pauseKeyEnabled,
            pauseKeyCode: pauseKeyCode,
            pausePressed: pausePressed,
            currentLanguage: currentLanguage,
            savedLanguage: savedLanguage
        )

        return PHTVModifierPressTransitionBox(
            lastFlags: flags,
            keyPressedWithRestoreModifier: nextKeyPressedWithRestoreModifier,
            restoreModifierPressed: nextRestoreModifierPressed,
            keyPressedWhileSwitchModifiersHeld: false,
            keyPressedWhileEmojiModifiersHeld: false,
            shouldUpdateLanguage: pausePressTransition.shouldUpdateLanguage,
            language: pausePressTransition.language,
            pausePressed: pausePressTransition.pausePressed,
            savedLanguage: pausePressTransition.savedLanguage
        )
    }

    @objc(modifierReleaseTransitionWithRestoreOnEscape:restoreModifierPressed:keyPressedWithRestoreModifier:customEscapeKey:oldFlags:newFlags:switchHotkey:convertHotkey:emojiEnabled:emojiModifiers:emojiKeyCode:keyPressedWhileSwitchModifiersHeld:keyPressedWhileEmojiModifiersHeld:hasJustUsedHotkey:tempOffSpellingEnabled:tempOffEngineEnabled:pauseKeyEnabled:pauseKeyCode:pausePressed:currentLanguage:savedLanguage:)
    class func modifierReleaseTransition(
        restoreOnEscape: Int32,
        restoreModifierPressed: Bool,
        keyPressedWithRestoreModifier: Bool,
        customEscapeKey: Int32,
        oldFlags: UInt64,
        newFlags: UInt64,
        switchHotkey: Int32,
        convertHotkey: Int32,
        emojiEnabled: Int32,
        emojiModifiers: Int32,
        emojiKeyCode: Int32,
        keyPressedWhileSwitchModifiersHeld: Bool,
        keyPressedWhileEmojiModifiersHeld: Bool,
        hasJustUsedHotkey: Bool,
        tempOffSpellingEnabled: Int32,
        tempOffEngineEnabled: Int32,
        pauseKeyEnabled: Int32,
        pauseKeyCode: Int32,
        pausePressed: Bool,
        currentLanguage: Int32,
        savedLanguage: Int32
    ) -> PHTVModifierReleaseTransitionBox {
        let releasePlan = evaluateFlagsReleasePlan(
            restoreOnEscape: restoreOnEscape,
            restoreModifierPressed: restoreModifierPressed,
            keyPressedWithRestoreModifier: keyPressedWithRestoreModifier,
            customEscapeKey: customEscapeKey,
            oldFlags: oldFlags,
            newFlags: newFlags,
            switchHotkey: switchHotkey,
            convertHotkey: convertHotkey,
            emojiEnabled: emojiEnabled,
            emojiModifiers: emojiModifiers,
            emojiKeyCode: emojiKeyCode,
            keyPressedWhileSwitchModifiersHeld: keyPressedWhileSwitchModifiersHeld,
            keyPressedWhileEmojiModifiersHeld: keyPressedWhileEmojiModifiersHeld,
            hasJustUsedHotkey: hasJustUsedHotkey,
            tempOffSpellingEnabled: tempOffSpellingEnabled,
            tempOffEngineEnabled: tempOffEngineEnabled
        )

        let pauseReleaseTransition = pauseTransitionForRelease(
            withOldFlags: oldFlags,
            newFlags: newFlags,
            pauseKeyEnabled: pauseKeyEnabled,
            pauseKeyCode: pauseKeyCode,
            pausePressed: pausePressed,
            currentLanguage: currentLanguage,
            savedLanguage: savedLanguage
        )

        return PHTVModifierReleaseTransitionBox(
            shouldAttemptRestore: flagsReleasePlanShouldAttemptRestore(releasePlan),
            shouldResetRestoreState: flagsReleasePlanShouldResetRestoreState(releasePlan),
            releaseAction: flagsReleasePlanModifierReleaseAction(releasePlan),
            shouldUpdateLanguage: pauseReleaseTransition.shouldUpdateLanguage,
            language: pauseReleaseTransition.language,
            pausePressed: pauseReleaseTransition.pausePressed,
            savedLanguage: pauseReleaseTransition.savedLanguage,
            lastFlags: 0,
            keyPressedWhileSwitchModifiersHeld: false,
            keyPressedWhileEmojiModifiersHeld: false
        )
    }

    @objc(sessionResetTransitionForCodeTable:allowUppercasePrime:safeMode:uppercaseEnabled:uppercaseExcluded:)
    class func sessionResetTransition(
        forCodeTable codeTable: Int32,
        allowUppercasePrime: Bool,
        safeMode: Bool,
        uppercaseEnabled: Int32,
        uppercaseExcluded: Int32
    ) -> PHTVSessionResetTransitionBox {
        let shouldClearSyncKey = (codeTable == 2 || codeTable == 3)
        var pendingUppercasePrimeCheck = true

        var shouldPrimeUppercaseFirstChar = false
        if allowUppercasePrime {
            shouldPrimeUppercaseFirstChar = PHTVAccessibilityService.shouldPrimeUppercaseFromAX(
                safeMode: safeMode,
                uppercaseEnabled: uppercaseEnabled != 0,
                uppercaseExcluded: uppercaseExcluded != 0
            )
            if shouldPrimeUppercaseFirstChar {
                pendingUppercasePrimeCheck = false
            }
        }

        return PHTVSessionResetTransitionBox(
            shouldClearSyncKey: shouldClearSyncKey,
            shouldPrimeUppercaseFirstChar: shouldPrimeUppercaseFirstChar,
            pendingUppercasePrimeCheck: pendingUppercasePrimeCheck,
            lastFlags: 0,
            willContinueSending: false,
            willSendControlKey: false,
            hasJustUsedHotKey: false
        )
    }

    @objc(shouldReleasePauseModeFromOldFlags:newFlags:pauseKeyCode:)
    class func shouldReleasePauseMode(fromOldFlags oldFlags: UInt64, newFlags: UInt64, pauseKeyCode: Int32) -> Bool {
        let pauseMask = pauseModifierMask(forKeyCode: pauseKeyCode)
        if pauseMask == 0 {
            return false
        }
        let wasPressed = (oldFlags & pauseMask) != 0
        let isPressed = (newFlags & pauseMask) != 0
        return wasPressed && !isPressed
    }

    @objc(pauseTransitionForPressWithFlags:pauseKeyEnabled:pauseKeyCode:pausePressed:currentLanguage:savedLanguage:)
    class func pauseTransitionForPress(
        withFlags flags: UInt64,
        pauseKeyEnabled: Int32,
        pauseKeyCode: Int32,
        pausePressed: Bool,
        currentLanguage: Int32,
        savedLanguage: Int32
    ) -> PHTVPauseTransitionBox {
        let action = evaluatePauseStateAction(
            oldFlags: 0,
            newFlags: flags,
            pauseKeyEnabled: pauseKeyEnabled,
            pauseKeyCode: pauseKeyCode,
            pausePressed: pausePressed
        )

        guard action == PHTVPauseStateAction.activate.rawValue else {
            return PHTVPauseTransitionBox(
                shouldUpdateLanguage: false,
                language: currentLanguage,
                pausePressed: pausePressed,
                savedLanguage: savedLanguage
            )
        }

        var nextLanguage = currentLanguage
        if currentLanguage == 1 {
            nextLanguage = 0
        }

        return PHTVPauseTransitionBox(
            shouldUpdateLanguage: nextLanguage != currentLanguage,
            language: nextLanguage,
            pausePressed: true,
            savedLanguage: currentLanguage
        )
    }

    @objc(pauseTransitionForReleaseWithOldFlags:newFlags:pauseKeyEnabled:pauseKeyCode:pausePressed:currentLanguage:savedLanguage:)
    class func pauseTransitionForRelease(
        withOldFlags oldFlags: UInt64,
        newFlags: UInt64,
        pauseKeyEnabled: Int32,
        pauseKeyCode: Int32,
        pausePressed: Bool,
        currentLanguage: Int32,
        savedLanguage: Int32
    ) -> PHTVPauseTransitionBox {
        let action = evaluatePauseStateAction(
            oldFlags: oldFlags,
            newFlags: newFlags,
            pauseKeyEnabled: pauseKeyEnabled,
            pauseKeyCode: pauseKeyCode,
            pausePressed: pausePressed
        )

        guard action == PHTVPauseStateAction.release.rawValue else {
            return PHTVPauseTransitionBox(
                shouldUpdateLanguage: false,
                language: currentLanguage,
                pausePressed: pausePressed,
                savedLanguage: savedLanguage
            )
        }

        return PHTVPauseTransitionBox(
            shouldUpdateLanguage: true,
            language: savedLanguage,
            pausePressed: false,
            savedLanguage: savedLanguage
        )
    }

    @objc(convertKeyStringToKeyCode:fallback:)
    class func convertKeyStringToKeyCode(_ keyString: String?, fallback: UInt16) -> Int32 {
        guard let keyString, !keyString.isEmpty else {
            return Int32(fallback)
        }

        if let keycode = layoutKeyStringToKeyCodeMap[keyString] {
            return Int32(keycode)
        }

        let lower = keyString.lowercased()
        if lower != keyString, let keycode = layoutKeyStringToKeyCodeMap[lower] {
            return Int32(keycode)
        }

        return Int32(fallback)
    }

    @objc class func invalidateLayoutCache() {
        PHTVCacheStateService.invalidateLayoutCache()
    }

    @objc(convertEventToKeyboardLayoutCompatKeyCode:fallback:)
    class func convertEventToKeyboardLayoutCompatKeyCode(_ event: CGEvent?, fallback: UInt16) -> UInt16 {
        guard let event else {
            return fallback
        }

        let rawKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if rawKeyCode < 256 {
            let cached = PHTVCacheStateService.cachedLayoutConversion(rawKeyCode)
            if cached != layoutCacheNoValue {
                return cached
            }
        }

        guard let layoutEvent = NSEvent(cgEvent: event) else {
            return fallback
        }

        var result = fallback
        let baseCharacters = layoutEvent.charactersIgnoringModifiers ?? ""
        let convertedBase = UInt16(
            truncatingIfNeeded: convertKeyStringToKeyCode(baseCharacters, fallback: layoutCacheNoValue)
        )
        if convertedBase != layoutCacheNoValue {
            result = convertedBase
        } else {
            let actualCharacters = layoutEvent.characters
            if let actualCharacters,
               actualCharacters != baseCharacters {
                let convertedActual = UInt16(
                    truncatingIfNeeded: convertKeyStringToKeyCode(actualCharacters, fallback: layoutCacheNoValue)
                )
                if convertedActual != layoutCacheNoValue {
                    result = convertedActual
                }
            }
        }

        if result == fallback,
           baseCharacters.count == 1,
           let azertyKeycode = azertyShiftedToNumber[baseCharacters] {
            result = azertyKeycode
        }

        if rawKeyCode < 256 {
            PHTVCacheStateService.setCachedLayoutConversion(rawKeyCode, result: result)
        }

        return result
    }
}
