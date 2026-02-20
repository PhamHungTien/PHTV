//
//  PHTVEngineDataBridge.swift
//  PHTV
//
//  Swift facade for engine data/dictionary APIs.
//

import Carbon
import Foundation

@objcMembers
final class PHTVEngineDataBridge: NSObject {
    class func initializeMacroMap(with data: Data) {
        data.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress
            PHTVEngineInitializeMacroMap(base, Int32(rawBuffer.count))
        }
    }

    class func initializeEnglishDictionary(atPath path: String) -> Bool {
        return path.withCString { cPath in
            PHTVEngineInitializeEnglishDictionary(cPath)
        }
    }

    class func englishDictionarySize() -> UInt {
        return UInt(PHTVEngineEnglishDictionarySize())
    }

    class func initializeVietnameseDictionary(atPath path: String) -> Bool {
        return path.withCString { cPath in
            PHTVEngineInitializeVietnameseDictionary(cPath)
        }
    }

    class func vietnameseDictionarySize() -> UInt {
        return UInt(PHTVEngineVietnameseDictionarySize())
    }

    class func initializeCustomDictionary(withJSONData jsonData: Data) {
        jsonData.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.bindMemory(to: CChar.self).baseAddress
            PHTVEngineInitializeCustomDictionary(base, Int32(rawBuffer.count))
        }
    }

    class func customEnglishWordCount() -> UInt {
        return UInt(PHTVEngineCustomEnglishWordCount())
    }

    class func customVietnameseWordCount() -> UInt {
        return UInt(PHTVEngineCustomVietnameseWordCount())
    }

    class func clearCustomDictionary() {
        PHTVEngineClearCustomDictionary()
    }

    class func setCheckSpellingValue(_ value: Int32) {
        PHTVEngineSetCheckSpellingValue(value)
    }

    private class func hotkeyKeyDisplayLabel(_ keyCode: UInt16) -> String {
        if keyCode == UInt16(kVK_Space) || Int32(keyCode) == Int32(PHTVEngineSpaceKeyCode()) {
            return "␣"
        }

        let keyChar = PHTVEngineHotkeyDisplayCharacter(keyCode)
        if keyChar >= 33,
           keyChar <= 126,
           let scalar = UnicodeScalar(Int(keyChar)) {
            return String(scalar)
        }

        return "KEY_\(keyCode)"
    }

    class func quickConvertMenuTitle() -> String {
        let quickConvertHotkey = Int32(PHTVEngineQuickConvertHotkey())
        var components: [String] = []

        if PHTVEngineHotkeyHasControl(quickConvertHotkey) {
            components.append("⌃")
        }
        if PHTVEngineHotkeyHasOption(quickConvertHotkey) {
            components.append("⌥")
        }
        if PHTVEngineHotkeyHasCommand(quickConvertHotkey) {
            components.append("⌘")
        }
        if PHTVEngineHotkeyHasShift(quickConvertHotkey) {
            components.append("⇧")
        }

        if PHTVEngineHotkeyHasKey(quickConvertHotkey) {
            let keyCode = PHTVEngineHotkeySwitchKey(quickConvertHotkey)
            components.append(hotkeyKeyDisplayLabel(keyCode))
        }

        if components.isEmpty {
            return "Chuyển mã nhanh"
        }
        return "Chuyển mã nhanh - [\(components.joined(separator: " + ").uppercased())]"
    }
}
