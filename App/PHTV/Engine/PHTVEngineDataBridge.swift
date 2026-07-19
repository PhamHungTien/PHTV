//
//  PHTVEngineDataBridge.swift
//  PHTV
//
//  Swift facade for engine data/dictionary APIs.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Carbon
import Foundation

private func phtvCallClearCustomDictionary() {
    phtvCustomDictionaryClear()
}

private func phtvCallStartNewSession() {
    phtvEngineStartNewSession()
}

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
            guard cPath[0] != 0 else {
                return false
            }
            return phtvDictionaryInitEnglish(cPath) != 0
        }
    }

    class func englishDictionarySize() -> UInt {
        return UInt(phtvDictionaryEnglishWordCount())
    }

    class func initializeVietnameseDictionary(atPath path: String) -> Bool {
        return path.withCString { cPath in
            guard cPath[0] != 0 else {
                return false
            }
            return phtvDictionaryInitVietnamese(cPath) != 0
        }
    }

    class func vietnameseDictionarySize() -> UInt {
        return UInt(phtvDictionaryVietnameseWordCount())
    }

    class func initializeCustomDictionary(withJSONData jsonData: Data) {
        jsonData.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.bindMemory(to: CChar.self).baseAddress
            phtvCustomDictionaryLoadJSON(base, Int32(rawBuffer.count))
        }
    }

    class func customEnglishWordCount() -> UInt {
        return UInt(phtvCustomDictionaryEnglishCount())
    }

    class func customVietnameseWordCount() -> UInt {
        return UInt(phtvCustomDictionaryVietnameseCount())
    }

    class func clearCustomDictionary() {
        phtvCallClearCustomDictionary()
    }

    class func startNewSession() {
        phtvCallStartNewSession()
    }

    private class func hotkeyKeyDisplayLabel(_ keyCode: UInt16) -> String {
        if keyCode == UInt16(kVK_Space) || keyCode == KeyCode.space {
            return "␣"
        }

        let keyChar = EngineMacroKeyMap.character(for: UInt32(keyCode) | EngineBitMask.caps)
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

        let charCodeMask = EngineBitMask.charCode
        let pureCharacterMask = EngineBitMask.pureCharacter

        var result = String()
        for data in macroData {
            if (data & pureCharacterMask) != 0 {
                let scalarValue = data & ~pureCharacterMask
                if let scalar = UnicodeScalar(scalarValue) {
                    result.unicodeScalars.append(scalar)
                }
                continue
            }

            if (data & charCodeMask) == 0 {
                let character = EngineMacroKeyMap.character(for: data)
                if character != 0 {
                    result.append(String(decoding: [character], as: UTF16.self))
                }
                continue
            }

            switch codeTable {
            case Int32(CodeTable.unicode.toIndex()):
                result.append(String(decoding: [UInt16(truncatingIfNeeded: data)], as: UTF16.self))
            case Int32(CodeTable.tcvn.toIndex()),
                 Int32(CodeTable.vniWindows.toIndex()),
                 Int32(CodeTable.cp1258.toIndex()):
                let low = EnginePackedData.lowByte(data)
                let high = EnginePackedData.highByte(data)
                result.append(String(decoding: [low], as: UTF16.self))
                if high > 32 {
                    result.append(String(decoding: [high], as: UTF16.self))
                }
            case Int32(CodeTable.unicodeComposite.toIndex()):
                var character = UInt16(truncatingIfNeeded: data)
                let markIndex = character >> 13
                character &= 0x1FFF
                result.append(String(decoding: [character], as: UTF16.self))
                if markIndex > 0 {
                    let mark = EnginePackedData.unicodeCompoundMark(at: Int32(markIndex) - 1)
                    result.append(String(decoding: [mark], as: UTF16.self))
                }
            default:
                continue
            }
        }

        return result
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
