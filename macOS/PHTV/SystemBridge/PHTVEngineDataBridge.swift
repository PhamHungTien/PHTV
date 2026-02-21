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
        if keyCode == UInt16(kVK_Space) || Int32(keyCode) == Int32(phtvEngineSpaceKeyCode()) {
            return "␣"
        }

        let keyChar = phtvEngineHotkeyDisplayCharacter(keyCode)
        if keyChar >= 33,
           keyChar <= 126,
           let scalar = UnicodeScalar(Int(keyChar)) {
            return String(scalar)
        }

        return "KEY_\(keyCode)"
    }

    class func quickConvertMenuTitle() -> String {
        let quickConvertHotkey = Int32(phtvEngineQuickConvertHotkey())
        var components: [String] = []

        if phtvEngineHotkeyHasControl(quickConvertHotkey) {
            components.append("⌃")
        }
        if phtvEngineHotkeyHasOption(quickConvertHotkey) {
            components.append("⌥")
        }
        if phtvEngineHotkeyHasCommand(quickConvertHotkey) {
            components.append("⌘")
        }
        if phtvEngineHotkeyHasShift(quickConvertHotkey) {
            components.append("⇧")
        }

        if phtvEngineHotkeyHasKey(quickConvertHotkey) {
            let keyCode = phtvEngineHotkeySwitchKey(quickConvertHotkey)
            components.append(hotkeyKeyDisplayLabel(keyCode))
        }

        if components.isEmpty {
            return "Chuyển mã nhanh"
        }
        return "Chuyển mã nhanh - [\(components.joined(separator: " + ").uppercased())]"
    }

    @objc(macroStringFromMacroData:count:codeTable:)
    class func macroString(
        fromMacroData macroData: UnsafePointer<UInt32>?,
        count: Int32,
        codeTable: Int32
    ) -> NSString {
        guard let macroData, count > 0 else {
            return ""
        }

        let capsMask = phtvEngineCapsMask()
        let charCodeMask = phtvEngineCharCodeMask()
        let pureCharacterMask = phtvEnginePureCharacterMask()

        var resultScalars = String.UnicodeScalarView()
        for index in 0..<Int(count) {
            let data = macroData[index]
            var character: UInt16 = 0

            if (data & pureCharacterMask) != 0 {
                character = UInt16(truncatingIfNeeded: data & ~capsMask)
            } else if (data & charCodeMask) == 0 {
                character = phtvEngineMacroKeyCodeToCharacter(data)
                if character == 0 {
                    continue
                }
            } else if codeTable == 0 {
                character = UInt16(truncatingIfNeeded: data & 0xFFFF)
            } else {
                character = phtvEngineLowByte(data)
            }

            guard character != 0, let scalar = UnicodeScalar(Int(character)) else {
                continue
            }
            resultScalars.append(scalar)
        }

        return String(resultScalars) as NSString
    }

    @objc(replaceSpotlightLikeMacroIfNeeded:backspaceCount:macroData:count:codeTable:safeMode:)
    class func replaceSpotlightLikeMacroIfNeeded(
        _ spotlightLike: Int32,
        backspaceCount: Int32,
        macroData: UnsafePointer<UInt32>?,
        count: Int32,
        codeTable: Int32,
        safeMode: Bool
    ) -> Bool {
        guard spotlightLike != 0 else {
            return false
        }

        let macroText = macroString(
            fromMacroData: macroData,
            count: count,
            codeTable: codeTable
        ) as String
        let shouldVerify = backspaceCount > 0

        return PHTVEventContextBridgeService.replaceFocusedTextViaAX(
            backspaceCount: backspaceCount,
            insertText: macroText,
            verify: shouldVerify,
            safeMode: safeMode
        )
    }
}
