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
            phtvLoadMacroMapFromBinary(base, Int32(rawBuffer.count))
        }
    }

    class func initializeEnglishDictionary(atPath path: String) -> Bool {
        return path.withCString { cPath in
            PHTVEngineRuntimeFacade.initializeEnglishDictionary(cPath)
        }
    }

    class func englishDictionarySize() -> UInt {
        return UInt(PHTVEngineRuntimeFacade.englishDictionarySize())
    }

    class func initializeVietnameseDictionary(atPath path: String) -> Bool {
        return path.withCString { cPath in
            PHTVEngineRuntimeFacade.initializeVietnameseDictionary(cPath)
        }
    }

    class func vietnameseDictionarySize() -> UInt {
        return UInt(PHTVEngineRuntimeFacade.vietnameseDictionarySize())
    }

    class func initializeCustomDictionary(withJSONData jsonData: Data) {
        jsonData.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.bindMemory(to: CChar.self).baseAddress
            PHTVEngineRuntimeFacade.initializeCustomDictionary(base, Int32(rawBuffer.count))
        }
    }

    class func customEnglishWordCount() -> UInt {
        return UInt(PHTVEngineRuntimeFacade.customEnglishWordCount())
    }

    class func customVietnameseWordCount() -> UInt {
        return UInt(PHTVEngineRuntimeFacade.customVietnameseWordCount())
    }

    class func clearCustomDictionary() {
        PHTVEngineRuntimeFacade.clearCustomDictionary()
    }

    private class func hotkeyKeyDisplayLabel(_ keyCode: UInt16) -> String {
        if keyCode == UInt16(kVK_Space) || Int32(keyCode) == PHTVEngineRuntimeFacade.spaceKeyCode() {
            return "␣"
        }

        let keyChar = PHTVEngineRuntimeFacade.hotkeyDisplayCharacter(keyCode)
        if keyChar >= 33,
           keyChar <= 126,
           let scalar = UnicodeScalar(Int(keyChar)) {
            return String(scalar)
        }

        return "KEY_\(keyCode)"
    }

    class func quickConvertMenuTitle() -> String {
        let quickConvertHotkey = PHTVConvertToolHotkeyService.currentHotkey()
        var components: [String] = []

        if PHTVConvertToolHotkeyService.hasControl(quickConvertHotkey) {
            components.append("⌃")
        }
        if PHTVConvertToolHotkeyService.hasOption(quickConvertHotkey) {
            components.append("⌥")
        }
        if PHTVConvertToolHotkeyService.hasCommand(quickConvertHotkey) {
            components.append("⌘")
        }
        if PHTVConvertToolHotkeyService.hasShift(quickConvertHotkey) {
            components.append("⇧")
        }

        if PHTVConvertToolHotkeyService.hasKey(quickConvertHotkey) {
            let keyCode = PHTVConvertToolHotkeyService.switchKey(quickConvertHotkey)
            components.append(hotkeyKeyDisplayLabel(keyCode))
        }

        if components.isEmpty {
            return "Chuyển mã nhanh"
        }
        return "Chuyển mã nhanh - [\(components.joined(separator: " + ").uppercased())]"
    }

    class func macroString(
        fromMacroData macroData: [UInt32],
        codeTable: Int32
    ) -> String {
        guard !macroData.isEmpty else {
            return ""
        }

        let capsMask = PHTVEngineRuntimeFacade.capsMask()
        let charCodeMask = PHTVEngineRuntimeFacade.charCodeMask()
        let pureCharacterMask = PHTVEngineRuntimeFacade.pureCharacterMask()

        var resultScalars = String.UnicodeScalarView()
        for data in macroData {
            var character: UInt16 = 0

            if (data & pureCharacterMask) != 0 {
                character = UInt16(truncatingIfNeeded: data & ~capsMask)
            } else if (data & charCodeMask) == 0 {
                character = PHTVEngineRuntimeFacade.macroKeyCodeToCharacter(data)
                if character == 0 {
                    continue
                }
            } else if codeTable == 0 {
                character = UInt16(truncatingIfNeeded: data & 0xFFFF)
            } else {
                character = PHTVEngineRuntimeFacade.lowByte(data)
            }

            guard character != 0, let scalar = UnicodeScalar(Int(character)) else {
                continue
            }
            resultScalars.append(scalar)
        }

        return String(resultScalars)
    }

    class func replaceSpotlightLikeMacroIfNeeded(
        _ spotlightLike: Int32,
        backspaceCount: Int32,
        macroData: [UInt32],
        codeTable: Int32,
        safeMode: Bool
    ) -> Bool {
        guard spotlightLike != 0 else {
            return false
        }

        let macroText = macroString(
            fromMacroData: macroData,
            codeTable: codeTable
        )
        let shouldVerify = backspaceCount > 0

        return PHTVEventContextBridgeService.replaceFocusedTextViaAX(
            backspaceCount: backspaceCount,
            insertText: macroText,
            verify: shouldVerify,
            safeMode: safeMode
        )
    }
}
